import SwiftUI

struct TagEditorView: View {
    @EnvironmentObject private var tagStore: TagStore
    let tagIDs: [UUID]
    let onAdd: (UUID) -> Void
    let onRemove: (UUID) -> Void
    @State private var newTagName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Tags")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if currentTags.isEmpty {
                Text("Type #tag in the text or add one below")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                FlowLayout(spacing: 7) {
                    ForEach(currentTags) { tag in
                        TagChip(tag: tag) {
                            onRemove(tag.id)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add tag", text: $newTagName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit(createAndAttach)
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                Menu {
                    if availableTags.isEmpty {
                        Text("No other tags")
                    } else {
                        ForEach(availableTags) { tag in
                            Button {
                                onAdd(tag.id)
                            } label: {
                                Label(tag.name, systemImage: "tag")
                            }
                        }
                    }
                } label: {
                    Label("Existing", systemImage: "tag")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .help("Use Existing Tag")

                Button(action: createAndAttach) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .disabled(TagStore.normalizedName(newTagName).isEmpty)
                .help("Create Tag")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPanel(cornerRadius: 4, tint: Theme.gold)
    }

    private var currentTags: [Tag] {
        tagIDs.compactMap { tagStore.tag(for: $0) }
    }

    private var availableTags: [Tag] {
        tagStore.tags
            .filter { !tagIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func createAndAttach() {
        guard let tag = tagStore.findOrCreate(named: newTagName) else { return }
        onAdd(tag.id)
        newTagName = ""
    }
}

private struct TagChip: View {
    let tag: Tag
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text("#\(tag.name)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textTertiary)
            .help("Remove Tag")
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Theme.gold.opacity(0.16), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Theme.gold.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var point = CGPoint.zero
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x > 0, point.x + size.width > width {
                point.x = 0
                point.y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            point.x += size.width + spacing
        }

        return CGSize(width: width, height: point.y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x > bounds.minX, point.x + size.width > bounds.maxX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: point, proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            point.x += size.width + spacing
        }
    }
}
