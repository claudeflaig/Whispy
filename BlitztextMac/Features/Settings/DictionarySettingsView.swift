import SwiftUI

/// Dictionary replacements, modelled on FoxSay: whole words in, other text or nothing out.
struct ReplacementRulesSection: View {
    @Binding var rules: [TextReplacementRule]
    @State private var sample = "Äh, ich wollte, ähm, kurz fragen, ob das passt. mfg"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ersetzungen")
                    .font(.raycast(size: 13.5, weight: .semibold))
                Text("Ganze Wörter werden nach dem Diktat ersetzt, Groß- und Kleinschreibung egal. Mehrere Auslöser trennst du mit Komma. Bleibt das Ersetzen-Feld leer, verschwindet das Wort, praktisch für Füllwörter.")
                    .font(.raycast(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if rules.isEmpty {
                    Text("Noch keine Ersetzungen.")
                        .font(.raycast(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                ForEach($rules) { $rule in
                    if rule.id != rules.first?.id {
                        Divider().opacity(0.5)
                    }
                    ReplacementRuleRow(rule: $rule) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            rules.removeAll { $0.id == rule.id }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            rules.append(TextReplacementRule(triggers: ""))
                        }
                    } label: {
                        Label("Ersetzung hinzufügen", systemImage: "plus")
                            .font(.raycast(size: 11, weight: .medium))
                    }
                    .glassButtonStyle()

                    Spacer()

                    Button {
                        let existing = Set(rules.map(\.triggers))
                        rules.append(contentsOf: TextReplacementRule.defaults.filter { !existing.contains($0.triggers) })
                    } label: {
                        Text("Füllwörter-Vorlage")
                            .font(.raycast(size: 11, weight: .medium))
                    }
                    .glassButtonStyle()
                    .help("Fügt die mitgelieferten Regeln für äh, ähm, hm und mfg wieder hinzu.")
                    .disabled(TextReplacementRule.defaults.allSatisfy { rule in rules.contains { $0.triggers == rule.triggers } })
                }
            }
            .settingsSection()

            VStack(alignment: .leading, spacing: 10) {
                Text("Ausprobieren")
                    .font(.raycast(size: 13.5, weight: .semibold))
                TextField("Beispielsatz", text: $sample, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.raycast(size: 11.5))
                    .lineLimit(1...3)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(TextReplacementService.apply(rules, to: sample))
                        .font(.raycast(size: 11.5, weight: .medium))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .settingsSection()
        }
    }
}

private struct ReplacementRuleRow: View {
    @Binding var rule: TextReplacementRule
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $rule.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(rule.isEnabled ? "Aktiv" : "Pausiert")

            TextField("Gesagt, z.B. äh, ähm", text: $rule.triggers)
                .textFieldStyle(.roundedBorder)
                .font(.raycast(size: 11))

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)

            TextField("Entfernen", text: $rule.replacement)
                .textFieldStyle(.roundedBorder)
                .font(.raycast(size: 11))

            Button(action: deleteAction) {
                Image(systemName: "trash")
                    .frame(width: 14, height: 14)
            }
            .help("Ersetzung löschen")
            .glassIconButtonStyle()
        }
        .opacity(rule.isEnabled ? 1 : 0.55)
    }
}
