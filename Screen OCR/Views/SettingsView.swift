import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)
            
            CaptureSettingsView()
                .tabItem {
                    Label("Capture", systemImage: "camera")
                }
                .tag(1)
            
            OCRSettingsView()
                .tabItem {
                    Label("OCR", systemImage: "text.viewfinder")
                }
                .tag(2)
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .padding()
        .frame(width: 550, height: 350)
    }
}

// MARK: - General Settings Tab
struct GeneralSettingsView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Launch & Behavior")
                .font(.headline)
                .padding(.bottom, 5)
            
            Toggle("Start at login", isOn: $viewModel.startAtLogin)
                .padding(.leading)
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Quick Capture", isOn: $viewModel.clickToScreenshot)
                        .padding(.leading)
                    
                    Text("Trigger capture with click on menu bar icon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 35)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Capture Settings Tab
struct CaptureSettingsView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Capture Hotkey")
                .font(.headline)
                .padding(.bottom, 5)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    // 修饰键选择
                    HStack {
                        ForEach(viewModel.modifierOptions, id: \.rawValue) { modifier in
                            Toggle(isOn: Binding(
                                get: { viewModel.selectedModifiers.contains(modifier) },
                                set: { isSelected in
                                    if isSelected {
                                        if !viewModel.selectedModifiers.contains(modifier) {
                                            viewModel.selectedModifiers.append(modifier)
                                        }
                                    } else {
                                        let remaining = viewModel.selectedModifiers.filter { $0 != modifier }
                                        if remaining.contains(where: { $0 != .shift }) {
                                            viewModel.selectedModifiers = remaining
                                        }
                                    }
                                }
                            )) {
                                Text(modifier.displayName)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 键码选择
                    Picker("", selection: $viewModel.selectedKeyCode) {
                        ForEach(viewModel.keyOptions, id: \.rawValue) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                    .frame(width: 100)
                }
                .padding(.leading)
            }
            
            Divider()
            
            Text("Capture Mode")
                .font(.headline)
                .padding(.bottom, 5)
            
            Picker("", selection: $viewModel.clipboardMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Normal Mode")
                    Text("Show floating window after capture")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(false)
            
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipboard Mode")
                    Text("Copy text directly to clipboard after capture")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
                .tag(true)
            }
            .pickerStyle(.radioGroup)
            .padding(.leading)

            Toggle("Play sound after copying", isOn: $viewModel.playSoundOnCopy)
                .padding(.leading, 44)
                .padding(.top, -8)
                .opacity(viewModel.clipboardMode ? 1 : 0)
                .disabled(!viewModel.clipboardMode)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - OCR Settings Tab
struct OCRSettingsView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("OCR Language")
                .font(.headline)
                .padding(.bottom, 5)
            
            Picker("Recognition Language", selection: $viewModel.selectedLanguage) {
                ForEach(viewModel.languageOptions, id: \.code) { option in
                    Text("\(getFlagEmoji(for: option.code)) \(getNativeLanguageName(for: option))")
                        .tag(option.code)
                }
            }
            .pickerStyle(DefaultPickerStyle())
//            .labelsHidden()
            .padding(.leading)
            .fixedSize()
            
            Text("Select the primary language for OCR recognition. Using \"Automatic\" will try to detect the language automatically.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 根据语言代码获取国旗表情符号
    private func getFlagEmoji(for languageCode: String) -> String {
        if languageCode == "auto" {
            return "🌐"
        }
        
        var countryCode: String
        
        // 根据语言代码提取或映射国家代码
        switch languageCode {
        case "en-US":
            countryCode = "US"
        case "fr-FR":
            countryCode = "FR"
        case "it-IT":
            countryCode = "IT"
        case "de-DE":
            countryCode = "DE"
        case "es-ES":
            countryCode = "ES"
        case "pt-BR":
            countryCode = "BR"
        case "zh-Hans", "zh-Hant": // 简体和繁体中文统一使用中国国旗
            countryCode = "CN"
        case "ko-KR":
            countryCode = "KR"
        case "ja-JP":
            countryCode = "JP"
        case "uk-UA":
            countryCode = "UA"
        case "ru-RU":
            countryCode = "RU"
        default:
            return ""
        }
        
        // 转换为区域指示符号
        let base: UInt32 = 127397 // Unicode码点基数
        var emoji = ""
        
        for scalar in countryCode.unicodeScalars {
            emoji.append(String(UnicodeScalar(base + scalar.value)!))
        }
        
        return emoji
    }
    
    // 获取语言的本地名称
    private func getNativeLanguageName(for option: (title: String, code: String)) -> String {
        switch option.code {
        case "auto":
            return "Automatic"
        case "en-US":
            return "English"
        case "fr-FR":
            return "Français"
        case "it-IT":
            return "Italiano"
        case "de-DE":
            return "Deutsch"
        case "es-ES":
            return "Español"
        case "pt-BR":
            return "Português"
        case "zh-Hans":
            return "简体中文"
        case "zh-Hant":
            return "繁體中文"
        case "ko-KR":
            return "한국어"
        case "ja-JP":
            return "日本語"
        case "uk-UA":
            return "Українська"
        case "ru-RU":
            return "Русский"
        default:
            return option.title
        }
    }
}

// MARK: - About Tab
struct AboutView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image("StatusBarIcon")
                .resizable()
                .frame(width: 64, height: 64)
            
            Text("Screen OCR")
                .font(.title)
            
            Text(viewModel.appVersion)
                .font(.caption)
            
            Text("A macOS app for capturing and recognizing text in screenshots.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Check for Updates") {
                if let url = URL(string: "https://github.com/lemos1235/ScreenOCR/releases") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SettingsViewModel())
    }
}
