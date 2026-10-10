import UIKit

final class CustomizeViewController: UINavigationController {
    init(store: LegacyStore) {
        super.init(rootViewController: SettingsTableController(store: store))
        title = "Customize"
        navigationBar.barStyle = .black
        navigationBar.barTintColor = Palette.ink
        navigationBar.tintColor = .white
        navigationBar.isTranslucent = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

class DarkTableController: UITableViewController {
    init() { super.init(style: .grouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = Palette.ink.withAlphaComponent(0.88)
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.12)
        tableView.rowHeight = 52
        tableView.estimatedRowHeight = 52
    }
    func cell(_ text: String, detail: String? = nil) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        cell.textLabel?.text = text; cell.textLabel?.textColor = .white
        cell.textLabel?.font = .systemFont(ofSize: 15)
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.detailTextLabel?.text = detail
        cell.detailTextLabel?.textColor = Palette.accent
        cell.selectedBackgroundView = UIView(); cell.selectedBackgroundView?.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return cell
    }
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Palette.accent
    }
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = UIColor.white.withAlphaComponent(0.7)
    }
}

final class SettingsTableController: DarkTableController {
    let store: LegacyStore
    init(store: LegacyStore) { self.store = store; super.init(); title = "Make it yours" }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); tableView.reloadData() }
    override func numberOfSections(in tableView: UITableView) -> Int { return 4 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section { case 0: return 4; case 1: return 2; case 2: return store.preferences.pages.count + 2; default: return 5 }
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ["Appearance", "Performance", "Home Screen pages", "Dock & reset"][section]
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "Built-in wallpapers and Core Graphics icons. Changes are saved on this device."
        case 1: return "Static glass is recommended for iPhone 6. Optional blur is limited to one visible surface and disabled by Low Power Mode or Reduce Transparency. System Reduce Motion is respected."
        case 2: return "Up to five pages with twelve apps each. Tap a page to add, remove or reorder icons. Removing a page removes only its layout."
        default: return "This app simulates a Home Screen. It cannot replace SpringBoard, intercept system gestures or read other apps’ notifications."
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let prefs = store.preferences
        let cell: UITableViewCell
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0: cell = self.cell("Wallpaper", detail: Wallpaper.names[prefs.wallpaper])
            case 1: cell = self.cell("Grid columns", detail: String(prefs.columns))
            case 2: cell = self.cell("Widget", detail: ["Date & time", "Device", "Demo weather", "None"][prefs.widget])
            default: cell = self.cell("Clear glass icons"); addToggle(cell, value: prefs.clearIcons, tag: 0)
            }
        case 1:
            if indexPath.row == 0 { cell = self.cell("Optional live blur"); addToggle(cell, value: prefs.blur, tag: 1) }
            else { cell = self.cell("Haptic feedback"); addToggle(cell, value: prefs.haptics, tag: 2) }
        case 2:
            if indexPath.row < prefs.pages.count { cell = self.cell("Page \(indexPath.row + 1)", detail: "\(prefs.pages[indexPath.row].count) apps") }
            else { cell = self.cell(indexPath.row == prefs.pages.count ? "Add page" : "Remove last page") }
        default:
            if indexPath.row < 4 { cell = self.cell("Dock position \(indexPath.row + 1)", detail: LegacyApp.find(prefs.dock[indexPath.row])?.title) }
            else { cell = self.cell("Reset appearance & layout") }
        }
        if cell.accessoryView == nil { cell.accessoryType = .disclosureIndicator }
        return cell
    }
    private func addToggle(_ cell: UITableViewCell, value: Bool, tag: Int) {
        let toggle = UISwitch(); toggle.isOn = value; toggle.tag = tag
        toggle.onTintColor = UIColor(red: 0.25, green: 0.6, blue: 0.8, alpha: 1)
        toggle.addTarget(self, action: #selector(changeToggle(_:)), for: .valueChanged)
        cell.accessoryView = toggle; cell.selectionStyle = .none
        toggle.accessibilityLabel = cell.textLabel?.text
    }
    @objc private func changeToggle(_ toggle: UISwitch) {
        store.update { prefs in
            if toggle.tag == 0 { prefs.clearIcons = toggle.isOn }
            else if toggle.tag == 1 { prefs.blur = toggle.isOn }
            else { prefs.haptics = toggle.isOn }
        }
        Motion.tap(store)
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let prefs = store.preferences
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0: choose("Wallpaper", options: Wallpaper.names, selected: prefs.wallpaper) { index in self.store.update { $0.wallpaper = index } }
            case 1: choose("Grid columns", options: ["3 columns", "4 columns"], selected: prefs.columns - 3) { index in self.store.update { $0.columns = index + 3 } }
            case 2: choose("Widget", options: ["Date & time", "Device battery & network", "Sample weather", "No widget"], selected: prefs.widget) { index in self.store.update { $0.widget = index } }
            default: break
            }
        case 2:
            if indexPath.row < prefs.pages.count { navigationController?.pushViewController(PageEditorController(store: store, page: indexPath.row), animated: true) }
            else if indexPath.row == prefs.pages.count {
                if prefs.pages.count < 5 { store.update { $0.pages.append([]) }; tableView.reloadData() }
                else { message("Five pages maximum", "Remove a page or customize an existing one.") }
            } else if prefs.pages.count > 1 { store.update { $0.pages.removeLast() }; tableView.reloadData() }
        case 3:
            if indexPath.row < 4 {
                let options = LegacyApp.catalog
                choose("Dock position \(indexPath.row + 1)", options: options.map { $0.title }, selected: options.firstIndex(where: { $0.id == prefs.dock[indexPath.row] }) ?? 0) { index in
                    self.store.update { $0.dock[indexPath.row] = options[index].id }
                }
            } else { store.update { $0 = Preferences() }; tableView.reloadData() }
        default: break
        }
    }
    private func choose(_ title: String, options: [String], selected: Int, onSelect: @escaping (Int) -> Void) {
        let controller = ChoiceTableController(title: title, options: options, selected: selected, onSelect: onSelect)
        navigationController?.pushViewController(controller, animated: true)
    }
}

final class ChoiceTableController: DarkTableController {
    private let options: [String]
    private let selected: Int
    private let onSelect: (Int) -> Void
    init(title: String, options: [String], selected: Int = -1, onSelect: @escaping (Int) -> Void) {
        self.options = options; self.selected = selected; self.onSelect = onSelect
        super.init(); self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return options.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.cell(options[indexPath.row]); cell.accessoryType = indexPath.row == selected ? .checkmark : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(indexPath.row); navigationController?.popViewController(animated: true)
    }
}

final class PageEditorController: DarkTableController {
    private let store: LegacyStore
    private let page: Int
    init(store: LegacyStore, page: Int) { self.store = store; self.page = page; super.init(); title = "Page \(page + 1)" }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.setEditing(true, animated: false)
        tableView.allowsSelectionDuringEditing = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .plain, target: self, action: #selector(addApp))
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); tableView.reloadData() }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return store.preferences.pages[page].count }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { return "Drag handles to reorder. Tap an app to move it to another page. Use Add to choose an icon from the built-in catalog." }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cell(LegacyApp.find(store.preferences.pages[page][indexPath.row])?.title ?? "App")
    }
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { return true }
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        store.update { prefs in let id = prefs.pages[page].remove(at: sourceIndexPath.row); prefs.pages[page].insert(id, at: destinationIndexPath.row) }
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        store.update { $0.pages[page].remove(at: indexPath.row) }
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let id = store.preferences.pages[page][indexPath.row]
        let destinations = store.preferences.pages.indices.filter { $0 != page && store.preferences.pages[$0].count < 12 && !store.preferences.pages[$0].contains(id) }
        guard !destinations.isEmpty else { message("No destination", "Add another page or make room on an existing one."); return }
        let choice = ChoiceTableController(title: "Move to page", options: destinations.map { "Page \($0 + 1)" }) { index in
            self.store.update { prefs in prefs.pages[self.page].removeAll { $0 == id }; prefs.pages[destinations[index]].append(id) }
        }
        navigationController?.pushViewController(choice, animated: true)
    }
    @objc private func addApp() {
        guard store.preferences.pages[page].count < 12 else { message("Page is full", "A page holds twelve icons. Remove an icon or add another page."); return }
        let apps = LegacyApp.catalog.filter { !store.preferences.pages[page].contains($0.id) }
        let choice = ChoiceTableController(title: "Add an app", options: apps.map { $0.title }) { index in
            self.store.update { $0.pages[self.page].append(apps[index].id) }
        }
        navigationController?.pushViewController(choice, animated: true)
    }
}
