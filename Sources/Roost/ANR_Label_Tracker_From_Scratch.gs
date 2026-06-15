/**
 * ANR Label Tracker - clean implementation.
 *
 * Paste this into a clean Apps Script project with no other .gs files.
 *
 * First run:
 *   rebuildTrackerFromLabel()
 *
 * Then install automation:
 *   setupTrigger()
 *
 * Optional:
 *   debugLabelReports()
 */

var CONFIG = {
  label: "Djibouti-ANR-Reports",
  spreadsheetName: "ANR Africa Payment Tracker",
  summaryEmail: "eatopriti@shridutt.com",
  dailySummaryHour: 16,
  pollIntervalHours: 6,
  gmailBatchSize: 100
};

var VERSION = "fresh-2026-06-12.11-master-format-fix";

var SHEETS = {
  dashboard: "Dashboard",
  outstanding: "Outstanding",
  advance: "Advance Receipt",
  lifting: "Pending Lifting",
  history: "History",
  missing: "Missing Review",
  salesperson: "By Salesperson",
  master: "Master Summary"
};

var REPORT_HEADERS = [
  "Report Date", "Source Subject", "PI Number", "Customer", "Amount (USD)",
  "Pending / Balance (USD)", "Funds Received (USD)", "Ageing (Days)",
  "Salesperson", "Status / Commodity"
];

var HISTORY_HEADERS = [
  "Processed At", "Report Date", "Report Type", "Source Subject", "PI Number",
  "Customer", "Amount (USD)", "Pending / Balance (USD)", "Funds Received (USD)",
  "Ageing (Days)", "Salesperson", "Status / Commodity"
];

var MISSING_HEADERS = [
  "First Missing At", "Last Seen Report Date", "Missing From", "PI Number",
  "Customer", "Amount (USD)", "Pending / Balance (USD)", "Funds Received (USD)",
  "Ageing (Days)", "Salesperson", "Status / Commodity", "Review Status", "Notes"
];

function rebuildTrackerFromLabel() {
  var props = PropertiesService.getScriptProperties();
  props.deleteProperty("TRACKER_SS_ID");
  props.deleteProperty("PROCESSED_MESSAGE_IDS");

  var ss = SpreadsheetApp.create(CONFIG.spreadsheetName + " - " + formatDate_(new Date(), "yyyy-MM-dd HH:mm"));
  props.setProperty("TRACKER_SS_ID", ss.getId());
  initializeSheets_(ss);
  removeDefaultSheet_(ss);

  processLabelMessages_({ processAll: true });
  console.log("Created tracker: " + ss.getUrl());
}

function runTracker() {
  processLabelMessages_({ processAll: false });
}

function setupTrigger() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === "runTracker") ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger("runTracker").timeBased().everyHours(CONFIG.pollIntervalHours).create();
  console.log("Installed runTracker trigger. Version=" + VERSION);
}

function setupDailySummaryTrigger() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === "sendDailySummary") ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger("sendDailySummary").timeBased().everyDays(1).atHour(CONFIG.dailySummaryHour).create();
  console.log("Installed sendDailySummary trigger at hour " + CONFIG.dailySummaryHour + ". Version=" + VERSION);
}

function setupAllTriggers() {
  setupTrigger();
  setupDailySummaryTrigger();
}

function debugLabelReports() {
  var messages = getMessagesForLabel_();
  console.log("Version=" + VERSION + " messages found under label=" + messages.length);
  messages.slice(0, 30).forEach(function(m) {
    var content = getMessageContent_(m);
    var type = detectType_(m.getSubject(), content.all);
    var rows = type ? parseReport_(content, type) : [];
    console.log([
      formatDate_(m.getDate(), "yyyy-MM-dd HH:mm:ss"),
      "skipForward=" + isForwardOrReply_(m.getSubject()),
      "type=" + type,
      "rows=" + rows.length,
      m.getSubject()
    ].join(" | "));
  });
}

function sendDailySummary() {
  runTracker();

  var ss = getOrCreateSpreadsheet_();
  rebuildMasterSummary_(ss);
  rebuildDashboard_(ss);

  var pdf = exportSheetAsPdf_(ss, ss.getSheetByName(SHEETS.master));
  var missingCount = countOpenMissing_(ss);
  var dateText = formatDate_(new Date(), "yyyy-MM-dd");

  MailApp.sendEmail({
    to: CONFIG.summaryEmail,
    subject: "ANR Africa Daily Payment Summary - " + dateText,
    body:
      "Daily master summary attached.\n\n" +
      "Outstanding, Advance Receipt, Pending Lifting, and Missing Review are included.\n" +
      "Open missing items: " + missingCount + "\n\n" +
      "Spreadsheet: " + ss.getUrl(),
    attachments: [pdf]
  });

  console.log("Sent daily summary to " + CONFIG.summaryEmail + " with openMissing=" + missingCount);
}

function processLabelMessages_(opts) {
  opts = opts || {};
  var ss = getOrCreateSpreadsheet_();
  initializeSheets_(ss);

  var processed = opts.processAll ? {} : getProcessedIds_();
  var messages = getMessagesForLabel_()
    .filter(function(m) { return opts.processAll || !processed[m.getId()]; })
    .sort(function(a, b) { return a.getDate() - b.getDate(); });

  var reports = [];
  messages.forEach(function(m) {
    if (isForwardOrReply_(m.getSubject())) {
      console.log("Skipped forwarded/reply: " + m.getSubject());
      processed[m.getId()] = true;
      return;
    }

    var content = getMessageContent_(m);
    var type = detectType_(m.getSubject(), content.all);
    if (!type) {
      console.log("Skipped unknown type: " + m.getSubject());
      processed[m.getId()] = true;
      return;
    }

    var rows = parseReport_(content, type);
    if (!rows.length) {
      console.log("Skipped zero-row report: " + type + " | " + m.getSubject());
      return;
    }

    reports.push({
      id: m.getId(),
      date: m.getDate(),
      type: type,
      subject: stripForwardPrefix_(m.getSubject()),
      rows: rows
    });
  });

  reports = dedupeReports_(reports);

  if (opts.processAll) {
    clearData_(ss.getSheetByName(SHEETS.history));
    clearData_(ss.getSheetByName(SHEETS.outstanding));
    clearData_(ss.getSheetByName(SHEETS.advance));
    clearData_(ss.getSheetByName(SHEETS.lifting));
    clearData_(ss.getSheetByName(SHEETS.missing));
  }

  reports.forEach(function(report) {
    appendHistory_(ss.getSheetByName(SHEETS.history), report);
    processed[report.id] = true;
  });

  var removed = dedupeHistory_(ss);
  rebuildCurrentSheetsFromHistory_(ss);
  rebuildMissingReviewFromHistory_(ss);
  rebuildSalesperson_(ss);
  rebuildMasterSummary_(ss);
  rebuildDashboard_(ss);
  saveProcessedIds_(processed);

  console.log(
    "Processed reports=" + reports.length +
    " removedHistoryDuplicates=" + removed +
    " spreadsheet=" + ss.getUrl()
  );
}

function detectType_(subject, body) {
  var s = (String(subject || "") + "\n" + String(body || "")).toLowerCase();
  if (/payment\s+received\s+but\s+pending\s+for\s+lifting/.test(s) || /pending\s+for\s+lifting/.test(s)) return "lifting";
  if (/advance\s+receipt/.test(s) || /daily\s+pi\s+advance/.test(s)) return "advance";
  if (/outstanding\s+payment/.test(s) || /no\s+funds\s+have\s+been\s+received/.test(s) || /funds\s+to\s+be\s+recd/.test(s)) return "outstanding";
  return null;
}

function parseReport_(content, type) {
  var sources = [content.html, content.plain, content.raw];
  var rows, i;

  for (i = 0; i < sources.length; i++) {
    rows = dedupeRowsByPi_(parseHtmlTables_(sources[i], type));
    if (rows.length) return rows;
  }

  for (i = 0; i < sources.length; i++) {
    rows = dedupeRowsByPi_(parseTextRows_(sources[i], type));
    if (rows.length) return rows;
  }

  return dedupeRowsByPi_(parsePiOnly_(content.all));
}

function parseHtmlTables_(html, type) {
  html = decodeQuotedPrintable_(html);
  var rows = [];
  var trRe = /<tr\b[\s\S]*?<\/tr>/gi;
  var tr;

  while ((tr = trRe.exec(html || "")) !== null) {
    var cells = [];
    var cellRe = /<t[dh]\b[^>]*>([\s\S]*?)<\/t[dh]>/gi;
    var cell;
    while ((cell = cellRe.exec(tr[0])) !== null) cells.push(htmlToText_(cell[1]));

    if (cells.length < 3 || !/^\d+$/.test(cells[0])) continue;
    var pi = normalizePi_(cells[1]);
    if (!isPi_(pi)) continue;

    rows.push(rowFromCells_(pi, cells, type));
  }

  return rows;
}

function rowFromCells_(pi, cells, type) {
  var customer = cells[2] || "";
  var amount = 0, pending = 0, received = 0, ageing = 0, sp = "", commodity = "";

  if (type === "outstanding") {
    commodity = cells[3] || "";
    amount = num_(cells[6]);
    received = num_(cells[10]);
    pending = num_(cells[11]);
    sp = cells[12] || "";
    ageing = int_(cells[14]);
  } else if (type === "advance") {
    amount = num_(cells[6]);
    received = num_(cells[10]);
    pending = num_(cells[11]);
    sp = cells[12] || "";
    ageing = int_(cells[14]);
  } else if (type === "lifting") {
    commodity = cells[4] || "";
    amount = num_(cells[7]);
    pending = num_(cells[10]);
    received = num_(cells[11]);
    ageing = int_(cells[13]);
  }

  return [pi, customer, amount, pending, received, ageing, sp, commodity];
}

function parseTextRows_(text, type) {
  text = htmlToText_(decodeQuotedPrintable_(text)).replace(/\s+/g, " ");
  var rows = [];
  var recRe = /(?:^|\s)\d{1,3}\s+((?:ANR|SK)\s*\d(?:\s*\d){6,11})\s+([\s\S]*?)(?=\s+\d{1,3}\s+(?:ANR|SK)\s*\d(?:\s*\d){6,11}\s+|\s+TOTAL\b|\s+Regards\b|$)/g;
  var m;

  while ((m = recRe.exec(text)) !== null) {
    var pi = normalizePi_(m[1]);
    if (!isPi_(pi)) continue;
    rows.push(rowFromText_(pi, m[2], type));
  }

  return rows;
}

function rowFromText_(pi, record, type) {
  record = String(record || "").replace(/\s+/g, " ").trim();
  var firstDate = (record.match(/\b\d{2}\/\d{2}\/\d{4}\b/) || [""])[0];
  var beforeDate = firstDate ? record.split(firstDate)[0].trim() : record;
  var split = splitCustomerCommodity_(beforeDate, type);
  var nums = extractNumbers_(record);

  var amount = nums.length > 2 ? nums[2] : 0;
  var received = nums.length > 6 ? nums[6] : 0;
  var pending = nums.length > 7 ? nums[7] : 0;
  if (type === "lifting") pending = nums.length > 5 ? nums[5] : 0;

  return [pi, split.customer, amount, pending, received, extractAgeing_(record), guessSalesperson_(record), split.commodity];
}

function parsePiOnly_(text) {
  text = decodeQuotedPrintable_(text).replace(/\s+/g, " ");
  var rows = [];
  var re = /\b(?:ANR|SK)\s*\d(?:\s*\d){6,11}\b/g;
  var m;
  while ((m = re.exec(text)) !== null) {
    var pi = normalizePi_(m[0]);
    if (isPi_(pi)) rows.push([pi, "", 0, 0, 0, 0, "", ""]);
  }
  return rows;
}

function appendHistory_(sh, report) {
  var processedAt = new Date();
  var data = report.rows.map(function(r) {
    return [processedAt, report.date, report.type, report.subject].concat(r);
  });
  if (data.length) sh.getRange(sh.getLastRow() + 1, 1, data.length, HISTORY_HEADERS.length).setValues(data);
}

function dedupeHistory_(ss) {
  var sh = ss.getSheetByName(SHEETS.history);
  var rows = readHistoryRows_(ss);
  if (!rows.length) return 0;

  var seen = {};
  var unique = [];
  var removed = 0;

  rows.forEach(function(row) {
    var key = historyRowKey_(row);
    if (seen[key]) {
      removed++;
      return;
    }
    seen[key] = true;
    unique.push(row);
  });

  unique.sort(function(a, b) {
    var da = asDate_(a[1]).getTime();
    var db = asDate_(b[1]).getTime();
    if (da !== db) return da - db;
    return stageOrder_(a[2]) - stageOrder_(b[2]);
  });

  clearData_(sh);
  if (unique.length) sh.getRange(2, 1, unique.length, HISTORY_HEADERS.length).setValues(unique);
  return removed;
}

function rebuildCurrentSheetsFromHistory_(ss) {
  var snapshots = buildSnapshotsFromHistory_(ss);
  ["outstanding", "advance", "lifting"].forEach(function(type) {
    var sh = ss.getSheetByName(sheetNameForType_(type));
    clearData_(sh);
    var list = snapshots[type] || [];
    if (!list.length) return;

    list.sort(function(a, b) { return a.date - b.date; });
    var latest = list[list.length - 1];
    var data = latest.rows.map(function(r) {
      return [latest.date, latest.subject].concat(r);
    });
    if (data.length) sh.getRange(2, 1, data.length, REPORT_HEADERS.length).setValues(data);
  });
}

function rebuildMissingReviewFromHistory_(ss) {
  var sh = ss.getSheetByName(SHEETS.missing);
  clearData_(sh);

  var snapshots = buildSnapshotsFromHistory_(ss);
  var missing = [];
  var seen = {};

  ["outstanding", "advance"].forEach(function(type) {
    var list = (snapshots[type] || []).slice().sort(function(a, b) { return a.date - b.date; });
    for (var i = 1; i < list.length; i++) {
      var previous = list[i - 1];
      var current = list[i];
      var currentSet = snapshotPiSet_(current);

      previous.rows.forEach(function(row) {
        var pi = normalizePi_(row[0]);
        if (!pi || currentSet[pi]) return;
        if (hasDownstreamOnOrAfter_(snapshots, type, pi, previous.date)) return;
        if (hasSameTypeAfter_(snapshots, type, pi, current.date)) return;

        var key = type + "|" + pi;
        if (seen[key]) return;
        seen[key] = true;

        missing.push([
          current.date, previous.date, type, pi, row[1], row[2], row[3], row[4],
          row[5], row[6], row[7], "Missing", ""
        ]);
      });
    }
  });

  missing.sort(function(a, b) { return a[0] - b[0]; });
  if (missing.length) sh.getRange(2, 1, missing.length, MISSING_HEADERS.length).setValues(missing);
}

function buildSnapshotsFromHistory_(ss) {
  var groups = {};
  readHistoryRows_(ss).forEach(function(row) {
    var reportDate = asDate_(row[1]);
    var type = String(row[2] || "").trim().toLowerCase();
    var subject = String(row[3] || "").trim();
    if (!reportDate || !type) return;

    var key = type + "|" + reportDate.getTime() + "|" + normalizeSubject_(subject);
    if (!groups[key]) groups[key] = { type: type, date: reportDate, subject: subject, rows: [] };
    groups[key].rows.push(row.slice(4, 12));
  });

  var snapshots = { outstanding: [], advance: [], lifting: [] };
  Object.keys(groups).forEach(function(k) {
    var snap = groups[k];
    snap.rows = dedupeRowsByPi_(snap.rows);
    if (snapshots[snap.type]) snapshots[snap.type].push(snap);
  });

  Object.keys(snapshots).forEach(function(type) {
    snapshots[type].sort(function(a, b) { return a.date - b.date; });
  });
  return snapshots;
}

function readHistoryRows_(ss) {
  var sh = ss.getSheetByName(SHEETS.history);
  if (!sh || sh.getLastRow() < 2) return [];
  return sh.getRange(2, 1, sh.getLastRow() - 1, HISTORY_HEADERS.length).getValues();
}

function hasDownstreamOnOrAfter_(snapshots, currentType, pi, sinceDate) {
  var types = getDownstreamTypes_(currentType);
  var since = sinceDate.getTime();
  for (var i = 0; i < types.length; i++) {
    var list = snapshots[types[i]] || [];
    for (var j = 0; j < list.length; j++) {
      if (list[j].date.getTime() >= since && snapshotPiSet_(list[j])[pi]) return true;
    }
  }
  return false;
}

function hasSameTypeAfter_(snapshots, type, pi, afterDate) {
  var list = snapshots[type] || [];
  var after = afterDate.getTime();
  for (var i = 0; i < list.length; i++) {
    if (list[i].date.getTime() > after && snapshotPiSet_(list[i])[pi]) return true;
  }
  return false;
}

function snapshotPiSet_(snapshot) {
  var set = {};
  snapshot.rows.forEach(function(r) {
    var pi = normalizePi_(r[0]);
    if (pi) set[pi] = true;
  });
  return set;
}

function getMessageContent_(m) {
  var api = getGmailApiContent_(m);
  if (api.html || api.plain) {
    return { plain: api.plain, html: api.html, raw: "", all: [api.plain, api.html].join("\n") };
  }

  var plain = "", html = "", raw = "";
  try { plain = m.getPlainBody() || ""; } catch(e1) {}
  try { html = m.getBody() || ""; } catch(e2) {}
  try { raw = m.getRawContent() || ""; } catch(e3) {}
  return { plain: plain, html: html, raw: raw, all: [plain, html, raw].join("\n") };
}

function getGmailApiContent_(m) {
  var out = { plain: "", html: "" };
  try {
    if (typeof Gmail === "undefined" || !Gmail.Users || !Gmail.Users.Messages) return out;
    var full = Gmail.Users.Messages.get("me", m.getId(), { format: "full" });
    walkGmailPart_(full.payload, out);
  } catch(e) {}
  return out;
}

function walkGmailPart_(part, out) {
  if (!part) return;
  var mime = String(part.mimeType || "").toLowerCase();
  if (part.body && part.body.data) {
    var decoded = decodeBase64Url_(part.body.data);
    if (mime === "text/plain") out.plain += "\n" + decoded;
    if (mime === "text/html") out.html += "\n" + decoded;
  }
  (part.parts || []).forEach(function(child) { walkGmailPart_(child, out); });
}

function getMessagesForLabel_() {
  var messages = [];
  var seen = {};
  var query = 'label:"' + CONFIG.label.replace(/"/g, '\\"') + '"';
  var start = 0;
  var threads;

  do {
    threads = GmailApp.search(query, start, CONFIG.gmailBatchSize);
    threads.forEach(function(t) {
      t.getMessages().forEach(function(m) {
        if (!seen[m.getId()]) {
          seen[m.getId()] = true;
          messages.push(m);
        }
      });
    });
    start += CONFIG.gmailBatchSize;
  } while (threads.length === CONFIG.gmailBatchSize);

  return messages;
}

function initializeSheets_(ss) {
  ensureSheet_(ss, SHEETS.outstanding, REPORT_HEADERS);
  ensureSheet_(ss, SHEETS.advance, REPORT_HEADERS);
  ensureSheet_(ss, SHEETS.lifting, REPORT_HEADERS);
  ensureSheet_(ss, SHEETS.history, HISTORY_HEADERS);
  ensureSheet_(ss, SHEETS.missing, MISSING_HEADERS);
  ensureSheet_(ss, SHEETS.salesperson, ["Salesperson", "Outstanding PIs", "Outstanding USD", "Advance PIs", "Advance USD", "Lifting PIs", "Lifting USD"]);
  ensureSheet_(ss, SHEETS.dashboard, ["Metric", "Value"]);
  ensureSheet_(ss, SHEETS.master, ["ANR Africa Master Summary"]);
  applySheetFormats_(ss);
}

function ensureSheet_(ss, name, headers) {
  var sh = ss.getSheetByName(name) || ss.insertSheet(name);
  if (sh.getLastRow() === 0) {
    sh.getRange(1, 1, 1, headers.length).setValues([headers]).setFontWeight("bold");
    sh.setFrozenRows(1);
  }
  return sh;
}

function applySheetFormats_(ss) {
  [SHEETS.outstanding, SHEETS.advance, SHEETS.lifting].forEach(function(name) {
    ss.getSheetByName(name).getRange("A:A").setNumberFormat("yyyy-mm-dd hh:mm");
  });
  ss.getSheetByName(SHEETS.history).getRange("A:B").setNumberFormat("yyyy-mm-dd hh:mm");
  ss.getSheetByName(SHEETS.missing).getRange("A:B").setNumberFormat("yyyy-mm-dd hh:mm");
}

function removeDefaultSheet_(ss) {
  var sh = ss.getSheetByName("Sheet1");
  if (sh && ss.getSheets().length > 1 && sh.getLastRow() === 0) ss.deleteSheet(sh);
}

function getOrCreateSpreadsheet_() {
  var props = PropertiesService.getScriptProperties();
  var id = props.getProperty("TRACKER_SS_ID");
  if (id) {
    try { return SpreadsheetApp.openById(id); } catch(e) {}
  }
  var ss = SpreadsheetApp.create(CONFIG.spreadsheetName);
  props.setProperty("TRACKER_SS_ID", ss.getId());
  return ss;
}

function rebuildMasterSummary_(ss) {
  var sh = ss.getSheetByName(SHEETS.master) || ensureSheet_(ss, SHEETS.master, ["ANR Africa Master Summary"]);
  sh.clear();

  var row = 1;
  var now = new Date();
  var outstanding = readCurrentRows_(ss.getSheetByName(SHEETS.outstanding));
  var advance = readCurrentRows_(ss.getSheetByName(SHEETS.advance));
  var lifting = readCurrentRows_(ss.getSheetByName(SHEETS.lifting));
  var missing = readCurrentRows_(ss.getSheetByName(SHEETS.missing));

  sh.getRange(row, 1, 1, 10).merge().setValue("ANR Africa Daily Summary").setFontSize(14).setFontWeight("bold");
  row++;
  sh.getRange(row, 1, 1, 2).setValues([["Generated", now]]);
  sh.getRange(row, 2).setNumberFormat("yyyy-mm-dd hh:mm");
  row += 2;

  row = writeMasterSection_(sh, row, "Outstanding", REPORT_HEADERS, outstanding);
  row = writeMasterSection_(sh, row + 2, "Advance Receipt", REPORT_HEADERS, advance);
  row = writeMasterSection_(sh, row + 2, "Pending Lifting", REPORT_HEADERS, lifting);
  row = writeMasterSection_(sh, row + 2, "Missing Review", MISSING_HEADERS, missing);

  sh.setFrozenRows(0);
  sh.getRange(1, 1, Math.max(row, 1), 13).setWrap(true).setVerticalAlignment("middle");
  sh.autoResizeColumns(1, 13);
  for (var c = 1; c <= 13; c++) {
    if (sh.getColumnWidth(c) > 220) sh.setColumnWidth(c, 220);
  }
}

function writeMasterSection_(sh, row, title, headers, data) {
  var width = headers.length;
  sh.getRange(row, 1, 1, width).merge().setValue(title).setFontWeight("bold").setBackground("#d9eaf7");
  row++;
  sh.getRange(row, 1, 1, width).setValues([headers]).setFontWeight("bold").setBackground("#f1f3f4");
  row++;

  if (data.length) {
    sh.getRange(row, 1, data.length, width).setValues(data);
    row += data.length;
  } else {
    sh.getRange(row, 1).setValue("No rows");
    row++;
  }

  return row;
}

function exportSheetAsPdf_(ss, sh) {
  var url =
    "https://docs.google.com/spreadsheets/d/" + ss.getId() + "/export" +
    "?format=pdf" +
    "&gid=" + sh.getSheetId() +
    "&size=A4" +
    "&portrait=false" +
    "&fitw=true" +
    "&sheetnames=false" +
    "&printtitle=false" +
    "&pagenumbers=false" +
    "&gridlines=false" +
    "&fzr=false";

  var response = UrlFetchApp.fetch(url, {
    headers: { Authorization: "Bearer " + ScriptApp.getOAuthToken() },
    muteHttpExceptions: true
  });

  if (response.getResponseCode() !== 200) {
    throw new Error("PDF export failed: HTTP " + response.getResponseCode() + " - " + response.getContentText());
  }

  return response.getBlob().setName("ANR Master Summary - " + formatDate_(new Date(), "yyyy-MM-dd") + ".pdf");
}

function rebuildDashboard_(ss) {
  var sh = ss.getSheetByName(SHEETS.dashboard);
  sh.clearContents();
  var rows = [
    ["ANR Africa Payment Tracker", ""],
    ["Version", VERSION],
    ["Updated At", new Date()],
    ["Spreadsheet", ss.getUrl()],
    ["", ""]
  ];
  [["outstanding", SHEETS.outstanding], ["advance", SHEETS.advance], ["lifting", SHEETS.lifting]].forEach(function(pair) {
    var data = readCurrentRows_(ss.getSheetByName(pair[1]));
    rows.push([pair[0] + " PIs", data.length]);
    rows.push([pair[0] + " amount", data.reduce(function(s, r) { return s + num_(r[4]); }, 0)]);
  });
  rows.push(["Open missing", countOpenMissing_(ss)]);
  sh.getRange(1, 1, rows.length, 2).setValues(rows);
  sh.getRange("B3:B3").setNumberFormat("yyyy-mm-dd hh:mm");
}

function rebuildSalesperson_(ss) {
  var sh = ss.getSheetByName(SHEETS.salesperson);
  clearData_(sh);
  var map = {};
  [[SHEETS.outstanding, 0], [SHEETS.advance, 2], [SHEETS.lifting, 4]].forEach(function(pair) {
    readCurrentRows_(ss.getSheetByName(pair[0])).forEach(function(r) {
      var sp = String(r[8] || "Unknown").trim() || "Unknown";
      if (!map[sp]) map[sp] = [0, 0, 0, 0, 0, 0];
      map[sp][pair[1]] += 1;
      map[sp][pair[1] + 1] += num_(r[4]);
    });
  });
  var rows = Object.keys(map).sort().map(function(sp) { return [sp].concat(map[sp]); });
  if (rows.length) sh.getRange(2, 1, rows.length, 7).setValues(rows);
}

function readCurrentRows_(sh) {
  if (!sh || sh.getLastRow() < 2) return [];
  return sh.getRange(2, 1, sh.getLastRow() - 1, sh.getLastColumn()).getValues();
}

function clearData_(sh) {
  if (sh && sh.getLastRow() > 1) sh.getRange(2, 1, sh.getLastRow() - 1, sh.getLastColumn()).clearContent();
}

function countOpenMissing_(ss) {
  var sh = ss.getSheetByName(SHEETS.missing);
  if (!sh || sh.getLastRow() < 2) return 0;
  return sh.getRange(2, 12, sh.getLastRow() - 1, 1).getValues().filter(function(r) {
    return String(r[0]) === "Missing";
  }).length;
}

function dedupeReports_(reports) {
  var seen = {};
  var out = [];
  reports.forEach(function(report) {
    var key = reportFingerprint_(report);
    if (seen[key]) return;
    seen[key] = true;
    out.push(report);
  });
  return out;
}

function dedupeRowsByPi_(rows) {
  var seen = {};
  var out = [];
  rows.forEach(function(row) {
    var pi = normalizePi_(row[0]);
    if (!pi || seen[pi]) return;
    seen[pi] = true;
    row[0] = pi;
    out.push(row);
  });
  return out;
}

function reportFingerprint_(report) {
  return [
    report.date.getTime(),
    report.type,
    normalizeSubject_(report.subject),
    report.rows.map(function(r) { return normalizePi_(r[0]) + ":" + num_(r[2]) + ":" + num_(r[3]) + ":" + num_(r[4]); }).sort().join("|")
  ].join("|");
}

function historyRowKey_(row) {
  return [
    asDate_(row[1]).getTime(),
    String(row[2] || "").trim().toLowerCase(),
    normalizeSubject_(row[3]),
    normalizePi_(row[4]),
    String(row[5] || "").trim().toUpperCase(),
    num_(row[6]), num_(row[7]), num_(row[8]), int_(row[9]),
    String(row[10] || "").trim().toUpperCase(),
    String(row[11] || "").trim().toUpperCase()
  ].join("|");
}

function sheetNameForType_(type) {
  if (type === "outstanding") return SHEETS.outstanding;
  if (type === "advance") return SHEETS.advance;
  if (type === "lifting") return SHEETS.lifting;
  throw new Error("Unknown report type: " + type);
}

function getDownstreamTypes_(type) {
  if (type === "outstanding") return ["advance", "lifting"];
  if (type === "advance") return ["lifting"];
  return [];
}

function stageOrder_(type) {
  if (type === "outstanding") return 1;
  if (type === "advance") return 2;
  if (type === "lifting") return 3;
  return 9;
}

function getProcessedIds_() {
  var raw = PropertiesService.getScriptProperties().getProperty("PROCESSED_MESSAGE_IDS");
  return raw ? JSON.parse(raw) : {};
}

function saveProcessedIds_(ids) {
  PropertiesService.getScriptProperties().setProperty("PROCESSED_MESSAGE_IDS", JSON.stringify(ids));
}

function isForwardOrReply_(subject) {
  return /^\s*(fwd?|fw|re)\s*:/i.test(String(subject || ""));
}

function stripForwardPrefix_(subject) {
  return String(subject || "").replace(/^(\s*(fwd?|fw|re)\s*:\s*)+/i, "").trim();
}

function normalizeSubject_(subject) {
  return stripForwardPrefix_(subject).toLowerCase();
}

function normalizePi_(pi) {
  return String(pi || "").replace(/\s+/g, "").trim().toUpperCase();
}

function isPi_(pi) {
  return /^(ANR|SK)\d{7,12}$/.test(normalizePi_(pi));
}

function splitCustomerCommodity_(text, type) {
  text = String(text || "").replace(/\s+/g, " ").trim();
  if (type === "advance") return { customer: text, commodity: "" };

  var words = text.split(" ");
  var start = -1;
  for (var i = 0; i < words.length; i++) {
    if (/%$/.test(words[i]) || /^(INDIAN|BROWN|SUGAR|RICE|PARBOILED|BROKEN|WHEAT|FLOUR|MAIZE|OIL|CEMENT|STEEL)$/i.test(words[i])) {
      start = i;
      break;
    }
  }
  if (start <= 0) return { customer: text, commodity: "" };
  return { customer: words.slice(0, start).join(" "), commodity: words.slice(start).join(" ") };
}

function guessSalesperson_(record) {
  var m = String(record || "").match(/\b(VPM|Mr\.\s+[A-Za-z]+(?:\s+[A-Za-z]+)?)\b/);
  return m ? m[1] : "";
}

function extractAgeing_(record) {
  var m = String(record || "").match(/\b\d{2}\/\d{2}\/\d{4}\s+(-?\d+)\s+(?:Expired|Valid)?\b/i);
  return m ? int_(m[1]) : 0;
}

function extractNumbers_(text) {
  var out = [];
  var re = /-?\d[\d,]*(?:\.\d+)?/g;
  var m;
  while ((m = re.exec(String(text || ""))) !== null) out.push(num_(m[0]));
  return out;
}

function htmlToText_(html) {
  return String(html || "")
    .replace(/<style\b[\s\S]*?<\/style>/gi, " ")
    .replace(/<script\b[\s\S]*?<\/script>/gi, " ")
    .replace(/<br\s*\/?\s*>/gi, "\n")
    .replace(/<\/tr>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/gi, '"')
    .replace(/\s+/g, " ")
    .trim();
}

function decodeQuotedPrintable_(text) {
  return String(text || "")
    .replace(/=\r?\n/g, "")
    .replace(/=([0-9A-Fa-f]{2})/g, function(_, hex) {
      return String.fromCharCode(parseInt(hex, 16));
    });
}

function decodeBase64Url_(data) {
  data = String(data || "").replace(/-/g, "+").replace(/_/g, "/");
  while (data.length % 4) data += "=";
  return Utilities.newBlob(Utilities.base64Decode(data)).getDataAsString("UTF-8");
}

function num_(v) {
  return parseFloat(String(v || "").replace(/,/g, "").replace(/[^0-9.-]/g, "")) || 0;
}

function int_(v) {
  return parseInt(String(v || "").replace(/,/g, "").replace(/[^0-9-]/g, ""), 10) || 0;
}

function asDate_(value) {
  if (value instanceof Date) return value;
  var d = new Date(value);
  return isNaN(d.getTime()) ? null : d;
}

function formatDate_(date, pattern) {
  return Utilities.formatDate(date instanceof Date ? date : new Date(date), Session.getScriptTimeZone(), pattern);
}
