#if os(iOS)

import UIKit

@available(iOS 11.0, *)
public protocol CountryCodePickerDelegate: AnyObject {
    func countryCodePickerViewControllerDidPickCountry(_ country: CountryCodePickerViewController.Country)
}

@available(iOS 11.0, *)
public class CountryCodePickerViewController: UITableViewController {

    lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.placeholder = NSLocalizedString(
            "PhoneNumberKit.CountryCodePicker.SearchBarPlaceholder",
            value: "Search Country Codes",
            comment: "Placeholder for country code search field")

        return searchController
    }()

    public let phoneNumberKit: PhoneNumberKit

    let commonCountryCodes: [String]

    var shouldRestoreNavigationBarToHidden = false

    var hasCurrent = true
    var hasCommon = true

    lazy public var allCountries = phoneNumberKit
        .allCountries()
        .compactMap({ Country(for: $0, with: self.phoneNumberKit) })
        .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })

    lazy var countries: [[Country]] = {
        let countries = allCountries
            .reduce([[Country]]()) { collection, country in
                var collection = collection
                guard var lastGroup = collection.last else { return [[country]] }
                let lhs = lastGroup.first?.name.folding(options: .diacriticInsensitive, locale: nil)
                let rhs = country.name.folding(options: .diacriticInsensitive, locale: nil)
                if lhs?.first == rhs.first {
                    lastGroup.append(country)
                    collection[collection.count - 1] = lastGroup
                } else {
                    collection.append([country])
                }
                return collection
            }

        let popular = commonCountryCodes.compactMap({ Country(for: $0, with: phoneNumberKit) })

        var result: [[Country]] = []
        // Note we should maybe use the user's current carrier's country code?
        if hasCurrent, let current = Country(for: PhoneNumberKit.defaultRegionCode(), with: phoneNumberKit) {
            result.append([current])
        }
        hasCommon = hasCommon && !popular.isEmpty
        if hasCommon {
            result.append(popular)
        }
        return result + countries
    }()

    var filteredCountries: [Country] = []

    public weak var delegate: CountryCodePickerDelegate?

    lazy var cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissAnimated))

    /**
     Init with a phone number kit instance. Because a PhoneNumberKit initialization is expensive you can must pass a pre-initialized instance to avoid incurring perf penalties.

     - parameter phoneNumberKit: A PhoneNumberKit instance to be used by the text field.
     - parameter commonCountryCodes: An array of country codes to display in the section below the current region section. defaults to `PhoneNumberKit.CountryCodePicker.commonCountryCodes`
     */
    public init(
        phoneNumberKit: PhoneNumberKit,
        commonCountryCodes: [String] = PhoneNumberKit.CountryCodePicker.commonCountryCodes)
    {
        self.phoneNumberKit = phoneNumberKit
        self.commonCountryCodes = commonCountryCodes
        super.init(style: .grouped)
        self.commonInit()
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black], for: .normal)
    }

    required init?(coder aDecoder: NSCoder) {
        self.phoneNumberKit = PhoneNumberKit()
        self.commonCountryCodes = PhoneNumberKit.CountryCodePicker.commonCountryCodes
        super.init(coder: aDecoder)
        self.commonInit()
    }

    func commonInit() {
        self.title = FuncApp.appIsArabic() ? "اختر البلد" : "Choose your country"
        tableView.register(Cell.self, forCellReuseIdentifier: Cell.reuseIdentifier)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.backgroundColor = bgColor
        searchController.searchBar.setDefaultSearchBar(bgColor: bgColor)
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    public var bgColor = UIColor(red: 0.471, green: 0.459, blue: 0.949, alpha: 1.0)
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        commonInit()
        //tableView.semanticContentAttribute = .forceLeftToRight
        tableView.sectionIndexColor = .white
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.singleLine
        tableView.separatorColor = (UIColor.white).withAlphaComponent(0.2)
        view.backgroundColor = bgColor
        if let nav = navigationController {
            shouldRestoreNavigationBarToHidden = nav.isNavigationBarHidden
            nav.setNavigationBarHidden(false, animated: true)
        }
        if let nav = navigationController, nav.isBeingPresented && nav.viewControllers.count == 1 {
            navigationItem.setRightBarButton(cancelButton, animated: true)
        }
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barTintColor = bgColor
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(shouldRestoreNavigationBarToHidden, animated: true)
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.barTintColor = nil
        navigationController?.navigationBar.shadowImage = nil
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        self.navigationController?.navigationBar.barTintColor = .white
    }

    @objc func dismissAnimated() {
        dismiss(animated: true)
    }

    func country(for indexPath: IndexPath) -> Country {
        isFiltering ? filteredCountries[indexPath.row] : countries[indexPath.section][indexPath.row]
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        isFiltering ? 1 : countries.count
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isFiltering ? filteredCountries.count : countries[section].count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Cell.reuseIdentifier, for: indexPath)
        cell.selectionStyle = .none
        let country = self.country(for: indexPath)
        cell.semanticContentAttribute = .forceLeftToRight
        cell.textLabel?.text = country.prefix + " " + country.flag
        cell.textLabel?.semanticContentAttribute = .forceLeftToRight
        cell.detailTextLabel?.semanticContentAttribute = .forceLeftToRight
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.text = country.name
        cell.detailTextLabel?.textColor = .white
        cell.textLabel?.font = .preferredFont(forTextStyle: .callout)
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        return cell
    }

    public override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var txt = ""
        txt = countries[section].first?.name.first.map(String.init) ?? ""
        if isFiltering {
            txt = ""
        } else if section == 0, hasCurrent {
            txt = FuncApp.appIsArabic() ? "الحالي" : "Current"
        } else if section == 0, !hasCurrent, hasCommon {
            txt = NSLocalizedString("PhoneNumberKit.CountryCodePicker.Common", value: "Common", comment: "Name of \"Common\" section")
        } else if section == 1, hasCurrent, hasCommon {
            txt = NSLocalizedString("PhoneNumberKit.CountryCodePicker.Common", value: "Common", comment: "Name of \"Common\" section")
        }
        let space:CGFloat = FuncApp.appIsArabic() ? 20.0 : 20.0
        let width:CGFloat = FuncApp.appIsArabic() ? 40.0 : 20.0

        let headerView = UIView(frame: CGRect(x: space, y: 0, width: tableView.frame.size.width-width, height: 30))
        headerView.backgroundColor = bgColor
        let label = UILabel(frame: headerView.frame)
        //label.semanticContentAttribute = .forceLeftToRight
        headerView.addSubview(label)
        label.textColor = .white
        label.text = txt
        return headerView
    }
    public override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    public override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard !isFiltering else {
            return nil
        }
        var titles: [String] = []
        if hasCurrent {
            titles.append("•") // NOTE: SFSymbols are not supported otherwise we would use 􀋑
        }
        if hasCommon {
            titles.append("★") // This is a classic unicode star
        }
        return titles + countries.suffix(countries.count - titles.count).map { group in
            group.first?.name.first
                .map(String.init)?
                .folding(options: .diacriticInsensitive, locale: nil) ?? ""
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let country = self.country(for: indexPath)
        delegate?.countryCodePickerViewControllerDidPickCountry(country)
        tableView.deselectRow(at: indexPath, animated: true)
        dismissAnimated()
    }
}

@available(iOS 11.0, *)
extension CountryCodePickerViewController: UISearchResultsUpdating {

    var isFiltering: Bool {
        searchController.isActive && !isSearchBarEmpty
    }

    var isSearchBarEmpty: Bool {
        searchController.searchBar.text?.isEmpty ?? true
    }

    public func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filteredCountries = allCountries.filter { country in
            country.name.lowercased().contains(searchText.lowercased()) ||
                country.code.lowercased().contains(searchText.lowercased()) ||
                country.prefix.lowercased().contains(searchText.lowercased())
        }
        tableView.reloadData()
    }
}


// MARK: Types

@available(iOS 11.0, *)
public extension CountryCodePickerViewController {

    struct Country {
        public var code: String
        public var flag: String
        public var name: String
        public var prefix: String

        public init?(for countryCode: String, with phoneNumberKit: PhoneNumberKit) {
            let flagBase = UnicodeScalar("🇦").value - UnicodeScalar("A").value
            guard
                let name = (Locale.current as NSLocale).localizedString(forCountryCode: countryCode),
                let prefix = phoneNumberKit.countryCode(for: countryCode)?.description
            else {
                return nil
            }

            self.code = countryCode
            self.name = name
            self.prefix = "+" + prefix
            self.flag = ""
            countryCode.uppercased().unicodeScalars.forEach {
                if let scaler = UnicodeScalar(flagBase + $0.value) {
                    flag.append(String(describing: scaler))
                }
            }
            if flag.count != 1 { // Failed to initialize a flag ... use an empty string
                return nil
            }
        }
    }

    class Cell: UITableViewCell {

        static let reuseIdentifier = "Cell"

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: .value2, reuseIdentifier: Self.reuseIdentifier)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

#endif

extension UISearchController {
    public func setDefaultSearchBar(bgColor: UIColor) {
        self.obscuresBackgroundDuringPresentation = false
        self.hidesNavigationBarDuringPresentation = false
        self.dimsBackgroundDuringPresentation = false
        self.searchBar.searchBarStyle = .minimal
        self.definesPresentationContext = true
        self.searchBar.setDefaultSearchBar(bgColor: bgColor)
    }
}
extension UISearchBar {
    public func setDefaultSearchBar(bgColor: UIColor) {
        self.tintColor = .darkGray
        self.barTintColor = .white
        self.backgroundColor = bgColor
        //UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.darkGray]
        
        textField.leftView?.tintColor = bgColor
        //textField.placeholder = "Search"//Localization.get("country_search_placeHolder", alternate: "Search")
        let redPlaceholderText = NSAttributedString(string: textField.placeholder ?? "", attributes: [NSAttributedString.Key.foregroundColor: UIColor.darkGray])
        textField.attributedPlaceholder = redPlaceholderText
        textField.backgroundColor = .white
        textField.textColor = .darkGray
        let textFieldInsideSearchBar = self.value(forKey: "searchField") as? UITextField

        textFieldInsideSearchBar?.textColor = .darkGray

        //setImage(UIImage(named: "clearIcon"), for: .clear, state: .normal)
        
    }
}
extension UISearchBar {
    /// Returns the`UITextField` that is placed inside the text field.
    var textField: UITextField {
        if #available(iOS 13, *) {
            return searchTextField
        } else {
            return self.value(forKey: "_searchField") as! UITextField
        }
    }
}

open class FuncApp : NSObject {
    public static func appIsArabic() -> Bool {
        return appCurrentLanguage() == "ar"
    }
    
    public static func appCurrentLanguage() -> String {
        return (Locale.current.identifier.components(separatedBy: "_").first ?? "en")
    }
}

