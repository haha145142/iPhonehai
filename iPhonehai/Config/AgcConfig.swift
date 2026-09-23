import Foundation

struct AgcConfig {
    private(set) var values: [String: String] = [:]

    init(dictionary: [String: String]) {
        values = dictionary
    }

    func string(_ key: String) -> String? { values[key] }

    func double(_ key: String, _ fallback: Double = 1.0) -> Double {
        guard let value = values[key], let number = Double(value) else { return fallback }
        return number
    }

    func int(_ key: String, _ fallback: Int = 0) -> Int {
        guard let value = values[key], let number = Int(value) else { return fallback }
        return number
    }
}

private final class AgcParser: NSObject, XMLParserDelegate {
    var values: [String: String] = [:]
    private var currentKey = ""
    private var currentText = ""

    func parse(data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if elementName == "string" {
            currentKey = attributeDict["name"] ?? ""
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "string", !currentKey.isEmpty {
            values[currentKey] = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentKey = ""
            currentText = ""
        }
    }
}

final class AgcConfigStore {
    static let shared = AgcConfigStore()

    private(set) var config: AgcConfig?
    private(set) var configName: String = "未加载配置"

    func load() {
        if let url = Bundle.main.url(
            forResource: "影踪追寻_通用配置",
            withExtension: "agc"
        ),
        let data = try? Data(contentsOf: url) {
            let parser = AgcParser()
            if parser.parse(data: data) {
                config = AgcConfig(dictionary: parser.values)
                configName = parser.values["pref_config_filename_key"] ?? "影踪追寻_通用配置.agc"
                return
            }
        }

        config = AgcConfig(dictionary: [
            "pref_config_filename_key": "影踪追寻_通用配置.agc",
            "lib_gamma_curve_preset_key_p15_0": "7",
            "lib_contrast_black_key_p11_0": "2.15",
            "lib_pref_satcct_c_key_p16_0": "1.0",
            "lib_pref_satcct_r_key_p8_0": "1.08",
            "lib_gpu_vignette_start_key_p3_0": "0",
            "lib_sabre_detail_key_p12_0": "30.0"
        ])
        configName = "影踪追寻_通用配置"
    }
}
