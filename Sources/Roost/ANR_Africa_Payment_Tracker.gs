/**
 * ANR Africa Payment Tracker
 * Paste this whole file into Google Apps Script.
 *
 * Main functions:
 * - runTracker()
 * - resetProcessedIdsAndReprocessLabel()
 * - setupAllTriggers()
 */

var CONFIG = {
  label:             "Djibouti-ANR-Reports",
  spreadsheetName:   "ANR Africa Payment Tracker",
  alertEmail:        "eatopriti@shridutt.com",
  alertThreshold:    200000,
  criticalAgeDays:   60,
  warningAgeDays:    30,
  maxStoredIds:      500,
  stalenessHours:    28,
  dailySummaryHour:  16,
  pollIntervalHours: 6,
  gmailBatchSize:    100,
};

var SCRIPT_VERSION = "2026-06-12.4-gmail-api-full";

var SHEET = {
  dashboard:   "MASTER DASHBOARD",
  outstanding: "Outstanding",
  advance:     "Advance Receipt",
  lifting:     "Pending Lifting",
  missing:     "Missing Review",
  history:     "History",
  salesperson: "By Salesperson",
};

var MR = {
  firstMissing:    1, lastSeen:        2, reportType:      3,
  piNumber:        4, customer:        5, amount:          6,
  pending:         7, fundsReceived:   8, ageing:          9,
  salesperson:    10, statusCommodity:11, reviewStatus:   12,
  notes:          13,
};

var MISSING_HEADERS = [
  "First Missing Date","Last Seen Date","Report Type","PI Number","Customer",
  "Amount (USD)","Pending / To Be Recd (USD)","Funds Received (USD)","Ageing (Days)",
  "Salesperson","Status / Commodity","Review Status","Notes"
];

var REPORT_COLS = [
  "Report Date","PI Number","Customer","Amount (USD)",
  "Pending (USD)","Funds Received (USD)","Ageing (Days)","Salesperson","Status / Commodity"
];

function fmtDate_(d) {
  return Utilities.formatDate(
    d instanceof Date ? d : new Date(d),
    Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm"
  );
}

function getProp_(k)    { return PropertiesService.getScriptProperties().getProperty(k); }
function setProp_(k, v) { PropertiesService.getScriptProperties().setProperty(k, v); }

function getSpreadsheet_() {
  var id = getProp_("SS_ID");
  if (id) { try { return SpreadsheetApp.openById(id); } catch(e) {} }
  var files = DriveApp.getFilesByName(CONFIG.spreadsheetName);
  var ss = files.hasNext()
    ? SpreadsheetApp.open(files.next())
    : SpreadsheetApp.create(CONFIG.spreadsheetName);
  setProp_("SS_ID", ss.getId());
  return ss;
}

function getOrCreateSheet_(ss, name, headers) {
  var sh = ss.getSheetByName(name) || ss.insertSheet(name);
  if (headers && headers.length && sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, headers.length)
      .setValues([headers])
      .setFontWeight("bold")
      .setBackground("#4a86e8")
      .setFontColor("#ffffff");
    sh.setFrozenRows(1);
  }
  return sh;
}

function getProcessedIds_() {
  var raw = getProp_("PROCESSED_IDS");
  return raw ? JSON.parse(raw) : {};
}

function saveProcessedIds_(ids) {
  var keys = Object.keys(ids);
  if (keys.length > CONFIG.maxStoredIds) {
    var trimmed = {};
    keys.slice(-CONFIG.maxStoredIds).forEach(function(k) { trimmed[k] = true; });
    ids = trimmed;
  }
  setProp_("PROCESSED_IDS", JSON.stringify(ids));
}

function resetProcessedIdsAndReprocessLabel() {
  PropertiesService.getScriptProperties().deleteProperty("PROCESSED_IDS");
  runTracker();
}

function diagnoseGmailLabel() {
  var ss = getSpreadsheet_();
  var label = GmailApp.getUserLabelByName(CONFIG.label);
  if (!label) {
    logRun_(ss, "DIAG: Label not found exactly: " + CONFIG.label);
    return;
  }

  var labelThreads = label.getThreads(0, 10);
  var searchQuery = 'label:"' + CONFIG.label.replace(/"/g, '\\"') + '"';
  var searchThreads = GmailApp.search(searchQuery, 0, 10);

  logRun_(ss,
    "DIAG: Label found: " + CONFIG.label +
    " | label.getThreads first batch: " + labelThreads.length +
    " | Gmail search first batch: " + searchThreads.length +
    " | search query: " + searchQuery
  );
}

function detectType_(subject, body) {
  var subjectText = String(subject || "")
    .replace(/^(\s*(fwd?|re)\s*:\s*)+/i, "")
    .toLowerCase();
  var s = (subjectText + " " + String(body || "")).toLowerCase();

  if (
    /payment\s+received\s+but\s+pending\s+for\s+lifting/.test(subjectText) ||
    /pending\s+for\s+lifting/.test(subjectText) ||
    /lifting\s+report/.test(subjectText) ||
    s.indexOf("pending for lifting") !== -1 ||
    s.indexOf("pending lifting") !== -1 ||
    s.indexOf("payment received but pending") !== -1
  ) return "lifting";

  if (
    subjectText.indexOf("daily pi advance receipt") !== -1 ||
    s.indexOf("advance receipt") !== -1 ||
    s.indexOf("advance receipt report") !== -1
  ) return "advance";

  if (
    subjectText.indexOf("daily pi outstanding payment") !== -1 ||
    s.indexOf("outstanding payment") !== -1 ||
    s.indexOf("no funds have been received") !== -1 ||
    s.indexOf("funds to be recd") !== -1
  ) return "outstanding";

  return null;
}

function parseEmailBody_(plainBody, type, htmlBody, rawBody) {
  plainBody = normalizeMimeText_(plainBody);
  htmlBody = normalizeMimeText_(htmlBody);
  rawBody = normalizeMimeText_(rawBody);

  var rows = parseHtmlReportRows_(htmlBody, type);
  if (rows.length) return rows;
  rows = parseHtmlReportRows_(rawBody, type);
  if (rows.length) return rows;
  rows = parseHtmlReportRows_(plainBody, type);
  if (rows.length) return rows;
  rows = parsePlainReportRows_(plainBody, type);
  if (rows.length) return rows;
  return parsePlainReportRows_(rawBody, type);
}

function getMessageBodies_(m) {
  var bodies = {
    plain: m.getPlainBody() || "",
    html:  m.getBody() || "",
    raw:   "",
  };

  try { bodies.raw = m.getRawContent() || ""; } catch(e) {}

  // Best path: enable Apps Script "Advanced Google services" -> Gmail API.
  // This returns MIME parts directly instead of GmailApp's sanitized/forwarded view.
  try {
    if (typeof Gmail !== "undefined" && Gmail.Users && Gmail.Users.Messages) {
      var full = Gmail.Users.Messages.get("me", m.getId(), { format: "full" });
      var apiParts = extractGmailApiBodies_(full.payload);
      if (apiParts.plain) bodies.plain = apiParts.plain + "\n" + bodies.plain;
      if (apiParts.html) bodies.html = apiParts.html + "\n" + bodies.html;
    }
  } catch(e2) {
    bodies.raw += "\nGMAIL_API_BODY_FETCH_FAILED: " + e2;
  }

  return bodies;
}

function extractGmailApiBodies_(payload) {
  var out = { plain: "", html: "" };

  function walk(part) {
    if (!part) return;

    var mimeType = String(part.mimeType || "").toLowerCase();
    var data = part.body && part.body.data ? decodeBase64Url_(part.body.data) : "";

    if (data && mimeType === "text/plain") out.plain += "\n" + data;
    if (data && mimeType === "text/html")  out.html  += "\n" + data;

    (part.parts || []).forEach(walk);
  }

  walk(payload);
  return out;
}

function decodeBase64Url_(data) {
  data = String(data || "").replace(/-/g, "+").replace(/_/g, "/");
  while (data.length % 4) data += "=";
  return Utilities.newBlob(Utilities.base64Decode(data)).getDataAsString("UTF-8");
}

function getLabeledMessages_(pIds) {
  var newMsgs = [];
  var start = 0;
  var threads;
  var query = 'label:"' + CONFIG.label.replace(/"/g, '\\"') + '"';

  do {
    threads = GmailApp.search(query, start, CONFIG.gmailBatchSize);
    threads.forEach(function(t) {
      t.getMessages().forEach(function(m) {
        if (!pIds[m.getId()]) newMsgs.push(m);
      });
    });
    start += CONFIG.gmailBatchSize;
  } while (threads.length === CONFIG.gmailBatchSize);

  if (newMsgs.length) return newMsgs;

  var label = GmailApp.getUserLabelByName(CONFIG.label);
  if (!label) return [];

  start = 0;
  do {
    threads = label.getThreads(start, CONFIG.gmailBatchSize);
    threads.forEach(function(t) {
      t.getMessages().forEach(function(m) {
        if (!pIds[m.getId()]) newMsgs.push(m);
      });
    });
    start += CONFIG.gmailBatchSize;
  } while (threads.length === CONFIG.gmailBatchSize);

  return newMsgs;
}

function parseHtmlReportRows_(html, type) {
  var rows = [];
  var trRe = /<tr\b[\s\S]*?<\/tr>/gi;
  var tr;

  while ((tr = trRe.exec(html || "")) !== null) {
    var cells = [];
    var cellRe = /<t[dh]\b[^>]*>([\s\S]*?)<\/t[dh]>/gi;
    var cell;

    while ((cell = cellRe.exec(tr[0])) !== null) {
      cells.push(htmlToText_(cell[1]));
    }

    if (cells.length < 3) continue;
    if (!/^\d+$/.test(cells[0])) continue;

    var pi = String(cells[1] || "").trim().toUpperCase();
    if (!/^[A-Z]{2,5}\d{7,12}$/.test(pi)) continue;

    var customer = cells[2] || "";
    var amount = 0, pending = 0, received = 0, ageing = 0, sp = "", status = "";

    if (type === "outstanding") {
      amount   = num_(cells[6]);
      pending  = num_(cells[11]);
      received = num_(cells[10]);
      sp       = cells[12] || "";
      ageing   = int_(cells[14]);
      status   = cells[3] || "";
    } else if (type === "advance") {
      amount   = num_(cells[6]);
      pending  = num_(cells[11]);
      received = num_(cells[10]);
      sp       = cells[12] || "";
      ageing   = int_(cells[14]);
      status   = cells[15] || "";
    } else if (type === "lifting") {
      amount   = num_(cells[7]);
      pending  = num_(cells[10]);
      received = num_(cells[11]);
      ageing   = int_(cells[13]);
      status   = [cells[4], cells[14]].filter(String).join(" | ");
    }

    rows.push([pi, customer, amount, pending, received, ageing, sp, status]);
  }

  return rows;
}

function debugReportSearch() {
  var ss = getSpreadsheet_();
  var queries = [
    'subject:"Payment Received But Pending For Lifting Report"',
    'subject:"Daily PI Advance Receipt Report"',
    'subject:"Daily PI Outstanding Payment Report"'
  ];
  var notes = [];

  queries.forEach(function(query) {
    var threads = GmailApp.search(query, 0, 10);
    notes.push("Query [" + query + "] threads=" + threads.length);
    threads.forEach(function(t) {
      t.getMessages().forEach(function(m) {
        var bodies = getMessageBodies_(m);
        var plain = bodies.plain;
        var html = bodies.html;
        var raw = bodies.raw;
        var type = detectType_(m.getSubject(), plain + "\n" + html + "\n" + raw);
        var rows = type ? parseEmailBody_(plain, type, html, raw) : [];
        notes.push(
          "Subject=" + m.getSubject() +
          " | type=" + type +
          " | rows=" + rows.length +
          " | plain=" + plain.length +
          " | html=" + html.length +
          " | raw=" + raw.length
        );
      });
    });
  });

  logRun_(ss, "DEBUG REPORT SEARCH v" + SCRIPT_VERSION + ": " + notes.join(" || "));
}

function debugReportSearchV5NoHelpers() {
  var queries = [
    { q: 'subject:"Payment Received But Pending For Lifting Report"', type: "lifting" },
    { q: 'subject:"Daily PI Advance Receipt Report"', type: "advance" },
    { q: 'subject:"Daily PI Outstanding Payment Report"', type: "outstanding" }
  ];
  var notes = [];

  queries.forEach(function(item) {
    var threads = GmailApp.search(item.q, 0, 10);
    notes.push("Query [" + item.q + "] threads=" + threads.length);
    threads.forEach(function(t) {
      t.getMessages().forEach(function(m) {
        var text = "";
        try { text += "\n" + (m.getPlainBody() || ""); } catch(e1) {}
        try { text += "\n" + (m.getBody() || ""); } catch(e2) {}
        try { text += "\n" + (m.getRawContent() || ""); } catch(e3) {}

        text = String(text || "")
          .replace(/=\r?\n/g, "")
          .replace(/=([0-9A-Fa-f]{2})/g, function(_, hex) {
            return String.fromCharCode(parseInt(hex, 16));
          })
          .replace(/<[^>]+>/g, " ")
          .replace(/\s+/g, " ");

        var seen = {};
        var pis = [];
        var re = /\b(?:ANR|SK)\s*\d(?:\s*\d){6,11}\b/g;
        var match;
        while ((match = re.exec(text)) !== null) {
          var pi = match[0].replace(/\s+/g, "").toUpperCase();
          if (!seen[pi]) {
            seen[pi] = true;
            pis.push(pi);
          }
        }

        notes.push(
          "Subject=" + m.getSubject() +
          " | forcedType=" + item.type +
          " | piCount=" + pis.length +
          " | firstPIs=" + pis.slice(0, 10).join(", ")
        );
      });
    });
  });

  var line = "DEBUG V5 NO HELPERS v" + SCRIPT_VERSION + ": " + notes.join(" || ");
  Logger.log(line);
  console.log(line);
}

function parsePlainReportRows_(body, type) {
  var rows = [];
  var seen = {};
  var text = normalizeMimeText_(body)
    .replace(/<style\b[\s\S]*?<\/style>/gi, " ")
    .replace(/<script\b[\s\S]*?<\/script>/gi, " ")
    .replace(/<\/t[dh]>/gi, " ")
    .replace(/<\/tr>/gi, "\n")
    .replace(/<br\s*\/?\s*>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/=\r?\n/g, "")
    .replace(/\r?\n/g, " ")
    .replace(/\s+/g, " ");

  var recRe = /(?:^|\s)(\d{1,3})\s+([A-Z]{2,5}\s*\d(?:\s*\d){6,11})\s+([\s\S]*?)(?=\s+\d{1,3}\s+[A-Z]{2,5}\s*\d(?:\s*\d){6,11}\s+|\s+TOTAL\b|\s+Regards\b|$)/g;
  var m;

  while ((m = recRe.exec(text)) !== null) {
    var pi = m[2].replace(/\s+/g, "").toUpperCase();
    if (seen[pi]) continue;
    seen[pi] = true;
    rows.push(buildRowFromPlainRecord_(pi, m[3], type));
  }

  if (!rows.length) {
    var piRe = /\b(?:ANR|SK)\s*\d(?:\s*\d){6,11}\b/g;
    while ((m = piRe.exec(text)) !== null) {
      var fallbackPi = m[0].replace(/\s+/g, "").toUpperCase();
      if (seen[fallbackPi]) continue;
      seen[fallbackPi] = true;
      rows.push([fallbackPi, "", 0, 0, 0, 0, "", ""]);
    }
  }

  return rows;
}

function buildRowFromPlainRecord_(pi, record, type) {
  record = String(record || "").replace(/\s+/g, " ").trim();

  var dates = record.match(/\b\d{2}\/\d{2}\/\d{4}\b/g) || [];
  var firstDate = dates.length ? dates[0] : "";
  var beforeFirstDate = firstDate ? record.split(firstDate)[0].trim() : record;
  var customer = guessCustomer_(beforeFirstDate, type);
  var nums = extractNumbers_(record);
  var amount = 0, pending = 0, received = 0, ageing = 0;
  var sp = guessSalesperson_(record);
  var status = guessStatus_(record, type);

  if (type === "outstanding") {
    amount = nums.length > 2 ? nums[2] : 0;
    received = nums.length > 6 ? nums[6] : 0;
    pending = nums.length > 7 ? nums[7] : 0;
    ageing = extractAgeingNearEnd_(record);
  } else if (type === "advance") {
    amount = nums.length > 2 ? nums[2] : 0;
    received = nums.length > 6 ? nums[6] : 0;
    pending = nums.length > 7 ? nums[7] : 0;
    ageing = extractAgeingNearStatus_(record);
  } else if (type === "lifting") {
    amount = nums.length > 2 ? nums[2] : 0;
    received = nums.length > 6 ? nums[6] : 0;
    pending = nums.length > 5 ? nums[5] : 0;
    ageing = extractAgeingNearStatus_(record);
  }

  return [pi, customer, amount, pending, received, ageing, sp, status];
}

function guessCustomer_(text, type) {
  text = String(text || "").trim();
  var markers = [
    "INDIAN SUGAR S30",
    "INDIAN BROWN SUGAR",
    "5% Broken Parboiled Rice",
    "100% Broken Rice"
  ];
  for (var i = 0; i < markers.length; i++) {
    var idx = text.indexOf(markers[i]);
    if (idx > 0) return text.slice(0, idx).trim();
  }
  return text;
}

function guessSalesperson_(record) {
  var m = String(record || "").match(/\b(VPM|Mr\.\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)\b/);
  return m ? m[1] : "";
}

function guessStatus_(record, type) {
  var commodity = "";
  ["INDIAN SUGAR S30", "INDIAN BROWN SUGAR", "5% Broken Parboiled Rice", "100% Broken Rice"].forEach(function(c) {
    if (!commodity && String(record || "").indexOf(c) !== -1) commodity = c;
  });
  var status = "";
  var m = String(record || "").match(/\b(Expired|Valid)\b/i);
  if (m) status = m[1];
  return [commodity, status].filter(String).join(" | ");
}

function extractNumbers_(text) {
  var out = [];
  var re = /-?\d[\d,]*(?:\.\d+)?/g;
  var m;
  while ((m = re.exec(String(text || ""))) !== null) {
    out.push(num_(m[0]));
  }
  return out;
}

function extractAgeingNearStatus_(record) {
  var m = String(record || "").match(/\b\d{2}\/\d{2}\/\d{4}\s+(-?\d+)\s+(?:Expired|Valid)\b/i);
  return m ? int_(m[1]) : 0;
}

function extractAgeingNearEnd_(record) {
  var m = String(record || "").match(/\b\d{2}\/\d{2}\/\d{4}\s+(-?\d+)(?:\s|$)/);
  return m ? int_(m[1]) : 0;
}

function normalizeMimeText_(text) {
  text = String(text || "");

  // Decode the common quoted-printable shape found in forwarded Gmail raw MIME.
  text = text.replace(/=\r?\n/g, "");
  text = text.replace(/=([0-9A-Fa-f]{2})/g, function(_, hex) {
    return String.fromCharCode(parseInt(hex, 16));
  });

  return text
    .replace(/\u00a0/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/gi, '"');
}

function htmlToText_(html) {
  return normalizeMimeText_(html)
    .replace(/<br\s*\/?\s*>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function num_(v) {
  return parseFloat(String(v || "").replace(/,/g, "").replace(/[^0-9.-]/g, "")) || 0;
}

function int_(v) {
  return parseInt(String(v || "").replace(/,/g, "").replace(/[^0-9-]/g, ""), 10) || 0;
}

function readSheetRows_(ss, sheetName) {
  var sh = ss.getSheetByName(sheetName);
  if (!sh || sh.getLastRow() < 2) return [];
  return sh.getRange(2, 1, sh.getLastRow() - 1, sh.getLastColumn()).getValues();
}

function writeReport_(ss, type, rows, reportDate) {
  var sh = getOrCreateSheet_(ss, SHEET[type], REPORT_COLS);
  if (sh.getLastRow() > 1)
    sh.getRange(2, 1, sh.getLastRow() - 1, sh.getLastColumn()).clearContent();
  if (!rows.length) return;
  var dateStr = fmtDate_(reportDate);
  sh.getRange(2, 1, rows.length, rows[0].length + 1)
    .setValues(rows.map(function(r) { return [dateStr].concat(r); }));
}

function appendToHistory_(ss, type, rows, reportDate) {
  var headers = [
    "Processed Date","Report Date","Type","PI Number","Customer",
    "Amount (USD)","Pending (USD)","Funds Received (USD)","Ageing (Days)",
    "Salesperson","Status / Commodity"
  ];
  var sh = getOrCreateSheet_(ss, SHEET.history, headers);
  var now = fmtDate_(new Date()), rDate = fmtDate_(reportDate);
  var data = rows.map(function(r) { return [now, rDate, type].concat(r); });
  if (data.length)
    sh.getRange(sh.getLastRow() + 1, 1, data.length, data[0].length).setValues(data);
}

function buildPISet_(rows, piIdx) {
  var s = {};
  rows.forEach(function(r) {
    var pi = String(r[piIdx] || "").trim().toUpperCase();
    if (pi) s[pi] = true;
  });
  return s;
}

function buildLivePIs_(ss, type, updates) {
  if (updates[type] && updates[type].length)
    return buildPISet_(updates[type], 0);
  return buildPISet_(readSheetRows_(ss, SHEET[type]), 1);
}

function checkMissingRows_(ss, type, oldRows, newRows, activePIs) {
  if (!oldRows.length) return 0;

  var mrSh   = getOrCreateSheet_(ss, SHEET.missing, MISSING_HEADERS);
  var now    = fmtDate_(new Date());
  var oldPIs = buildPISet_(oldRows, 1);
  var newPIs = buildPISet_(newRows, 0);

  var mrRows = mrSh.getLastRow() > 1
    ? mrSh.getRange(2, 1, mrSh.getLastRow() - 1, MISSING_HEADERS.length).getValues()
    : [];

  var keyMap = {};
  mrRows.forEach(function(row, i) {
    var key = String(row[MR.piNumber - 1]).trim().toUpperCase() + "|" +
              String(row[MR.reportType - 1]).trim().toLowerCase();
    keyMap[key] = { rowNum: i + 2, status: String(row[MR.reviewStatus - 1]).trim() };
  });

  mrRows.forEach(function(row, i) {
    if (String(row[MR.reportType - 1]).trim().toLowerCase() !== type) return;
    if (String(row[MR.reviewStatus - 1]).trim() !== "Missing") return;
    var pi = String(row[MR.piNumber - 1]).trim().toUpperCase();
    if (newPIs[pi]) {
      mrSh.getRange(i + 2, MR.reviewStatus).setValue("Reappeared");
      mrSh.getRange(i + 2, MR.notes).setValue("Reappeared in " + type + " as of " + now);
    }
  });

  var toAdd = [];
  Object.keys(oldPIs).forEach(function(pi) {
    if (newPIs[pi]) return;
    if (activePIs[pi]) return;

    var key = pi + "|" + type;
    if (keyMap[key] && keyMap[key].status === "Missing") return;

    var src = null;
    for (var i = 0; i < oldRows.length; i++) {
      if (String(oldRows[i][1]).trim().toUpperCase() === pi) { src = oldRows[i]; break; }
    }
    if (!src) return;

    toAdd.push([
      now, src[0], type, src[1], src[2], src[3], src[4], src[5], src[6],
      src[7], src[8], "Missing", ""
    ]);
  });

  if (toAdd.length)
    mrSh.getRange(mrSh.getLastRow() + 1, 1, toAdd.length, toAdd[0].length).setValues(toAdd);

  return toAdd.length;
}

function reconcileMissingReview_(ss) {
  var mrSh = ss.getSheetByName(SHEET.missing);
  if (!mrSh || mrSh.getLastRow() < 2) return;

  var now    = fmtDate_(new Date());
  var mrRows = mrSh.getRange(2, 1, mrSh.getLastRow() - 1, MISSING_HEADERS.length).getValues();

  var current = {};
  ["outstanding","advance","lifting"].forEach(function(t) {
    current[t] = buildPISet_(readSheetRows_(ss, SHEET[t]), 1);
  });

  mrRows.forEach(function(row, i) {
    if (String(row[MR.reviewStatus - 1]).trim() !== "Missing") return;
    var pi   = String(row[MR.piNumber - 1]).trim().toUpperCase();
    var type = String(row[MR.reportType - 1]).trim().toLowerCase();
    ["outstanding","advance","lifting"].forEach(function(t) {
      if (t === type) return;
      if (current[t][pi]) {
        mrSh.getRange(i + 2, MR.reviewStatus).setValue("Progressed");
        mrSh.getRange(i + 2, MR.notes).setValue("Progressed to: " + t + " as of " + now);
      }
    });
  });
}

function countMissing_(ss) {
  var sh = ss.getSheetByName(SHEET.missing);
  if (!sh || sh.getLastRow() < 2) return 0;
  return sh.getRange(2, MR.reviewStatus, sh.getLastRow() - 1, 1)
    .getValues()
    .filter(function(r) { return String(r[0]).trim() === "Missing"; })
    .length;
}

function rebuildDashboard_(ss) {
  var sh  = getOrCreateSheet_(ss, SHEET.dashboard, []);
  sh.clearContents();
  var now          = new Date();
  var missingCount = countMissing_(ss);

  var data = [
    ["ANR Africa Payment Tracker", ""],
    ["Last Updated", fmtDate_(now)],
    ["", ""],
  ];

  [
    { key: "outstanding", label: "Outstanding Payments" },
    { key: "advance",     label: "Advance Receipts" },
    { key: "lifting",     label: "Pending Lifting" },
  ].forEach(function(t) {
    var rows  = readSheetRows_(ss, SHEET[t.key]);
    var total = rows.reduce(function(s, r) { return s + (parseFloat(r[3]) || 0); }, 0);
    var lastDate = rows.length ? String(rows[0][0]) : "-";
    var stale    = false;
    if (rows.length) {
      var d = new Date(lastDate);
      if (!isNaN(d.getTime())) stale = (now - d) / 3600000 > CONFIG.stalenessHours;
    }
    data.push([t.label, ""]);
    data.push(["  PIs", rows.length]);
    data.push(["  Total (USD)", total.toLocaleString("en-US")]);
    data.push(["  Last Report", lastDate + (stale ? "  STALE" : "")]);
    data.push(["", ""]);
  });

  data.push(["Missing Review", ""]);
  data.push([
    "  Open Alerts",
    missingCount > 0 ? missingCount + "  - ACTION REQUIRED" : "0  - All Clear"
  ]);

  sh.getRange(1, 1, data.length, 2).setValues(data);
  sh.getRange(1, 1, 1, 2).setFontSize(14).setFontWeight("bold");
  if (missingCount > 0) {
    sh.getRange(data.length, 1, 1, 2)
      .setBackground("#ea4335").setFontColor("#ffffff").setFontWeight("bold");
  }
}

function rebuildSalesperson_(ss) {
  var headers = [
    "Salesperson",
    "Outstanding PIs","Outstanding (USD)",
    "Advance PIs","Advance (USD)",
    "Lifting PIs","Lifting (USD)"
  ];
  var sh = getOrCreateSheet_(ss, SHEET.salesperson, headers);
  if (sh.getLastRow() > 1)
    sh.getRange(2, 1, sh.getLastRow() - 1, headers.length).clearContent();

  var spMap = {};
  ["outstanding","advance","lifting"].forEach(function(t, ti) {
    readSheetRows_(ss, SHEET[t]).forEach(function(r) {
      var sp = String(r[7] || "Unknown").trim() || "Unknown";
      if (!spMap[sp]) spMap[sp] = [0, 0, 0, 0, 0, 0];
      spMap[sp][ti * 2]     += 1;
      spMap[sp][ti * 2 + 1] += parseFloat(r[3]) || 0;
    });
  });

  var rows = Object.keys(spMap).sort().map(function(sp) { return [sp].concat(spMap[sp]); });
  if (rows.length) sh.getRange(2, 1, rows.length, headers.length).setValues(rows);
}

function getDashboardBlob_(ss) {
  var sh = ss.getSheetByName(SHEET.dashboard);
  if (!sh) return null;
  var gid   = sh.getSheetId();
  var token = ScriptApp.getOAuthToken();
  var base  = "https://docs.google.com/spreadsheets/d/" + ss.getId() + "/export?gid=" + gid;

  try {
    var r = UrlFetchApp.fetch(base + "&format=png&fitw=true",
      { headers: { Authorization: "Bearer " + token }, muteHttpExceptions: true });
    if (r.getResponseCode() === 200) return r.getBlob().setName("dashboard.png");
  } catch(e) {}

  try {
    var r2 = UrlFetchApp.fetch(base + "&format=pdf&size=A3&portrait=false&fitw=true",
      { headers: { Authorization: "Bearer " + token }, muteHttpExceptions: true });
    if (r2.getResponseCode() === 200) return r2.getBlob().setName("dashboard.pdf");
  } catch(e) {}

  return null;
}

function sendMissingAlert_(ss, newCount) {
  if (newCount <= 0) return;
  var sh = ss.getSheetByName(SHEET.missing);
  var missingRows = [];
  if (sh && sh.getLastRow() > 1) {
    sh.getRange(2, 1, sh.getLastRow() - 1, MISSING_HEADERS.length)
      .getValues()
      .forEach(function(r) {
        if (String(r[MR.reviewStatus - 1]).trim() === "Missing") missingRows.push(r);
      });
  }

  var lines = [newCount + " PI(s) disappeared from all reports.\n"];
  missingRows.slice(0, 20).forEach(function(r) {
    lines.push(
      r[MR.piNumber - 1] + "  |  " + r[MR.customer - 1] +
      "  |  " + r[MR.reportType - 1] +
      "  |  Last seen: " + r[MR.lastSeen - 1]
    );
  });

  MailApp.sendEmail({
    to:      CONFIG.alertEmail,
    subject: "[ANR Alert] " + newCount + " PI(s) missing from all reports - " + fmtDate_(new Date()).split(" ")[0],
    body:    lines.join("\n"),
  });
}

function sendDailySummary() {
  sendSummaryEmail_(getSpreadsheet_());
}

function sendSummaryEmail_(ss) {
  var missingCount = countMissing_(ss);
  var blob         = getDashboardBlob_(ss);
  var dateStr      = fmtDate_(new Date()).split(" ")[0];
  var note         = missingCount > 0
    ? missingCount + " PI(s) are missing from all reports and require review. Check the Missing Review sheet."
    : "No missing items detected across all reports.";

  var opts = {
    to:      CONFIG.alertEmail,
    subject: "ANR Africa Daily Payment Summary - " + dateStr,
    body:    "Daily dashboard attached.\n\n" + note,
  };

  if (blob) {
    var isPng = blob.getName().endsWith(".png");
    opts.attachments = [blob];
    opts.htmlBody = (isPng ? '<img src="cid:dashboard" style="max-width:100%"><br><br>' : "") +
                    "<p>" + note + "</p>";
    if (isPng) opts.inlineImages = { dashboard: blob };
  }

  MailApp.sendEmail(opts);
}

function logRun_(ss, msg) {
  var line = fmtDate_(new Date()) + " | " + msg;
  Logger.log(line);
  console.log(line);
}

function runTracker() {
  var ss   = getSpreadsheet_();
  var pIds = getProcessedIds_();

  var label = GmailApp.getUserLabelByName(CONFIG.label);
  if (!label) { logRun_(ss, "Label not found: " + CONFIG.label); return; }

  var newMsgs = getLabeledMessages_(pIds);

  if (!newMsgs.length) { logRun_(ss, "No new messages. v" + SCRIPT_VERSION); return; }

  var updates     = {};
  var reportDates = {};
  var parseNotes  = [];

  newMsgs.forEach(function(m) {
    var bodies = getMessageBodies_(m);
    var plain = bodies.plain;
    var html  = bodies.html;
    var raw = bodies.raw;
    var type  = detectType_(m.getSubject(), plain + "\n" + html + "\n" + raw);

    if (!type) {
      parseNotes.push("Skipped unknown type: " + m.getSubject() +
        " | plain chars: " + plain.length +
        " | html chars: " + html.length +
        " | raw chars: " + raw.length);
      return;
    }

    var rows = parseEmailBody_(plain, type, html, raw);
    parseNotes.push(type + ": " + rows.length + " row(s) from " + m.getSubject() +
      " | plain chars: " + plain.length +
      " | html chars: " + html.length +
      " | raw chars: " + raw.length);

    if (!rows.length) {
      return;
    }

    if (!reportDates[type] || m.getDate() > reportDates[type]) {
      updates[type]     = rows;
      reportDates[type] = m.getDate();
    }
    pIds[m.getId()] = true;
  });

  var updatedTypes = Object.keys(updates);
  if (!updatedTypes.length) {
    saveProcessedIds_(pIds);
    logRun_(ss, "No valid reports parsed. v" + SCRIPT_VERSION + " | " + parseNotes.join(" | "));
    return;
  }

  var oldRows = {};
  ["outstanding","advance","lifting"].forEach(function(t) {
    oldRows[t] = readSheetRows_(ss, SHEET[t]);
  });

  var totalNewMissing = 0;
  updatedTypes.forEach(function(type) {
    var activePIs = {};
    ["outstanding","advance","lifting"].filter(function(t) { return t !== type; })
      .forEach(function(t) {
        var live = buildLivePIs_(ss, t, updates);
        Object.keys(live).forEach(function(pi) { activePIs[pi] = true; });
      });

    totalNewMissing += checkMissingRows_(ss, type, oldRows[type], updates[type], activePIs);
  });

  updatedTypes.forEach(function(type) {
    writeReport_(ss, type, updates[type], reportDates[type]);
    appendToHistory_(ss, type, updates[type], reportDates[type]);
    setProp_("LAST_" + type.toUpperCase(), fmtDate_(reportDates[type]));
  });

  reconcileMissingReview_(ss);
  rebuildDashboard_(ss);
  rebuildSalesperson_(ss);

  if (totalNewMissing > 0) sendMissingAlert_(ss, totalNewMissing);

  saveProcessedIds_(pIds);
  logRun_(ss, "v" + SCRIPT_VERSION + " | Messages: " + newMsgs.length +
    " | Updated: " + updatedTypes.join(", ") +
    " | New missing: " + totalNewMissing +
    " | Parse: " + parseNotes.join(" | "));
}

function setupTrigger() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === "runTracker") ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger("runTracker").timeBased().everyHours(CONFIG.pollIntervalHours).create();
}

function setupDailySummaryTrigger() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === "sendDailySummary") ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger("sendDailySummary").timeBased().everyDays(1).atHour(CONFIG.dailySummaryHour).create();
}

function setupAllTriggers() {
  setupTrigger();
  setupDailySummaryTrigger();
}
