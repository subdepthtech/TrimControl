import Foundation

public enum FileTypeGroupID: String, CaseIterable, Codable, Identifiable, Sendable {
    case markdownVault = "markdown-vault"
    case textConfigData = "text-config-data"
    case scriptsSource = "scripts-source"

    public var id: String { rawValue }
}

public struct ExportedTypeDefinition: Hashable, Sendable {
    public let identifier: String
    public let description: String
    public let extensions: [String]
    public let conformsTo: [String]

    public init(
        identifier: String,
        description: String,
        extensions: [String],
        conformsTo: [String]
    ) {
        self.identifier = identifier
        self.description = description
        self.extensions = extensions
        self.conformsTo = conformsTo
    }
}

public struct FileTypeContentDefinition: Hashable, Sendable {
    public let identifier: String
    public let description: String
    public let extensions: [String]

    public init(
        identifier: String,
        description: String,
        extensions: [String]
    ) {
        self.identifier = identifier
        self.description = description
        self.extensions = extensions
    }
}

public struct FileTypeChoice: Identifiable, Hashable, Sendable {
    public let id: String
    public let groupID: FileTypeGroupID
    public let title: String
    public let extensions: [String]
    public let contentTypes: [String]
    public let isCustom: Bool

    public init(
        id: String,
        groupID: FileTypeGroupID,
        title: String,
        extensions: [String],
        contentTypes: [String],
        isCustom: Bool = false
    ) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.extensions = extensions
        self.contentTypes = contentTypes
        self.isCustom = isCustom
    }

    public var displayExtensions: String {
        if extensions.isEmpty {
            return "No direct extension"
        }

        return extensions.map { ".\($0)" }.joined(separator: ", ")
    }
}

public struct FileTypeGroup: Identifiable, Hashable, Sendable {
    public let id: FileTypeGroupID
    public let title: String
    public let shortTitle: String
    public let summary: String
    public let systemImage: String
    public let extensions: [String]
    public let stableTypes: [FileTypeContentDefinition]
    public let exportedTypes: [ExportedTypeDefinition]

    public var contentTypes: [String] {
        stableTypes.map(\.identifier) + exportedTypes.map(\.identifier)
    }

    public var displayExtensions: String {
        extensions.map { ".\($0)" }.joined(separator: ", ")
    }

    public var fileTypeChoices: [FileTypeChoice] {
        let mergedExportedTypeIdentifiers: Set<String> = [
            "\(AppConstants.bundleIdentifier).tsx",
        ]

        let stableChoices = stableTypes.map { type in
            var contentTypes = [type.identifier]
            if type.identifier == "com.microsoft.typescript" {
                contentTypes.append("\(AppConstants.bundleIdentifier).tsx")
            }

            return FileTypeChoice(
                id: type.identifier,
                groupID: id,
                title: type.description,
                extensions: type.extensions,
                contentTypes: contentTypes
            )
        }

        let exportedChoices = exportedTypes
            .filter { !mergedExportedTypeIdentifiers.contains($0.identifier) }
            .map { type in
                FileTypeChoice(
                    id: type.identifier,
                    groupID: id,
                    title: type.description,
                    extensions: type.extensions,
                    contentTypes: [type.identifier]
                )
            }

        return stableChoices + exportedChoices
    }
}

public enum FileTypeCatalog {
    private static let markdownConformance = ["net.daringfireball.markdown", "public.plain-text"]
    private static let markdownSourceConformance = [
        "net.daringfireball.markdown",
        "public.source-code",
        "public.plain-text",
    ]
    private static let jsonTextConformance = ["public.json", "public.plain-text"]
    private static let textConformance = ["public.plain-text"]
    private static let sourceConformance = ["public.source-code"]
    private static let scriptConformance = ["public.source-code", "public.script"]

    public static let groups: [FileTypeGroup] = [
        FileTypeGroup(
            id: .markdownVault,
            title: "Markdown",
            shortTitle: "Markdown",
            summary: "Markdown documents and vault companion files.",
            systemImage: "doc.text",
            extensions: [
                "md", "markdown", "mdown", "mkd", "mkdn", "mdx", "qmd", "rmd", "prompt",
                "plan", "todo", "prd", "runbook", "sop", "spec", "dashboard",
            ],
            stableTypes: [
                stable("net.daringfireball.markdown", "Markdown", ["md", "markdown"]),
            ],
            exportedTypes: [
                exported("mdown", "Markdown aliases", ["mdown", "mkd", "mkdn"], markdownConformance),
                exported("mdx", "MDX document", ["mdx"], markdownSourceConformance),
                exported("qmd", "Quarto Markdown document", ["qmd"], markdownConformance),
                exported("rmd", "R Markdown document", ["rmd"], markdownConformance),
                exported("prompt", "Prompt Markdown document", ["prompt"], markdownConformance),
                exported("plan", "Plan Markdown document", ["plan"], markdownConformance),
                exported("todo", "Todo Markdown document", ["todo"], markdownConformance),
                exported("prd", "PRD Markdown document", ["prd"], markdownConformance),
                exported("runbook", "Runbook Markdown document", ["runbook"], markdownConformance),
                exported("sop", "SOP Markdown document", ["sop"], markdownConformance),
                exported("spec", "Spec Markdown document", ["spec"], markdownConformance),
                exported("dashboard", "Dashboard Markdown document", ["dashboard"], markdownConformance),
            ]
        ),
        FileTypeGroup(
            id: .textConfigData,
            title: "Text, Config, and Data",
            shortTitle: "Text",
            summary: "Plain text, structured data, config, and dotfile companions.",
            systemImage: "curlybraces",
            extensions: [
                "txt", "text", "log", "json", "jsonl", "jsonc", "yaml", "yml", "toml", "xml",
                "plist", "csv", "tsv", "ndjson", "json5", "hjson", "cson", "jsonlines",
                "ldjson", "env", "envrc", "dotenv", "env.example", "env.local",
                "env.production", "env.development", "env.test", "conf", "cfg", "config",
                "ini", "properties", "editorconfig", "gitignore", "gitattributes",
                "gitmodules", "gitconfig", "gitkeep", "dockerignore", "npmignore",
                "prettierignore", "eslintignore", "stylelintignore", "markdownlintignore",
                "ignore", "hgignore", "npmrc", "yarnrc", "prettierrc", "eslintrc",
                "babelrc", "browserslistrc", "commitlintrc", "stylelintrc", "yamllint",
                "markdownlint", "sqlfluff", "graphqlrc", "tool-versions", "nvmrc",
                "node-version", "ruby-version", "python-version", "lock", "ron", "edn",
                "base", "canvas",
            ],
            stableTypes: [
                stable("public.text", "Text documents", ["txt", "text"]),
                stable("public.plain-text", "Plain text", ["txt", "text"]),
                stable("com.apple.log", "Log", ["log"]),
                stable("public.json", "JSON", ["json"]),
                stable("public.yaml", "YAML", ["yaml", "yml"]),
                stable("public.toml", "TOML", ["toml"]),
                stable("public.xml", "XML", ["xml"]),
                stable("com.apple.property-list", "Property list", ["plist"]),
                stable("public.comma-separated-values-text", "CSV", ["csv"]),
                stable("public.tab-separated-values-text", "TSV", ["tsv"]),
                stable("public.ndjson", "NDJSON", ["ndjson"]),
                stable("com.microsoft.ini", "INI", ["ini"]),
            ],
            exportedTypes: [
                exported("jsonl", "JSON Lines document", ["jsonl"], textConformance),
                exported("jsonc", "JSONC document", ["jsonc"], textConformance),
                exported("json5", "JSON5 document", ["json5"], textConformance),
                exported("hjson", "HJSON document", ["hjson"], textConformance),
                exported("cson", "CSON document", ["cson"], textConformance),
                exported("jsonlines", "JSON Lines aliases", ["jsonlines", "ldjson"], textConformance),
                exported(
                    "env",
                    "Environment file",
                    [
                        "env", "envrc", "dotenv", "env.example", "env.local", "env.production",
                        "env.development", "env.test",
                    ],
                    textConformance
                ),
                exported("conf", "Configuration file", ["conf", "cfg", "config"], textConformance),
                exported("properties", "Properties file", ["properties"], textConformance),
                exported("editorconfig", "EditorConfig file", ["editorconfig"], textConformance),
                exported("gitignore", "Git ignore file", ["gitignore"], textConformance),
                exported("gitattributes", "Git attributes file", ["gitattributes"], textConformance),
                exported("gitmodules", "Git modules file", ["gitmodules"], textConformance),
                exported("gitconfig", "Git config file", ["gitconfig"], textConformance),
                exported("gitkeep", "Git keep marker", ["gitkeep"], textConformance),
                exported(
                    "ignore",
                    "Ignore file",
                    [
                        "dockerignore", "npmignore", "prettierignore", "eslintignore",
                        "stylelintignore", "markdownlintignore", "ignore", "hgignore",
                    ],
                    textConformance
                ),
                exported("npmrc", "npm configuration file", ["npmrc"], textConformance),
                exported("yarnrc", "Yarn configuration file", ["yarnrc"], textConformance),
                exported("prettierrc", "Prettier configuration file", ["prettierrc"], textConformance),
                exported("eslintrc", "ESLint configuration file", ["eslintrc"], textConformance),
                exported("babelrc", "Babel configuration file", ["babelrc"], textConformance),
                exported(
                    "tool-rc",
                    "Tool configuration file",
                    [
                        "browserslistrc", "commitlintrc", "stylelintrc", "yamllint",
                        "markdownlint", "sqlfluff", "graphqlrc",
                    ],
                    textConformance
                ),
                exported("tool-versions", "Tool versions file", ["tool-versions"], textConformance),
                exported(
                    "runtime-version",
                    "Runtime version file",
                    ["nvmrc", "node-version", "ruby-version", "python-version"],
                    textConformance
                ),
                exported("lock", "Lock file", ["lock"], textConformance),
                exported("ron", "RON document", ["ron"], textConformance),
                exported("edn", "EDN document", ["edn"], textConformance),
                exported("base", "Obsidian Bases file", ["base"], textConformance),
                exported("canvas", "Obsidian Canvas file", ["canvas"], jsonTextConformance),
            ]
        ),
        FileTypeGroup(
            id: .scriptsSource,
            title: "Scripts and Source",
            shortTitle: "Source",
            summary: "Scripts, source code, markup, styles, and infrastructure code.",
            systemImage: "terminal",
            extensions: [
                "sh", "zsh", "bash", "fish", "ps1", "py", "rb", "pl", "php", "js", "jsx",
                "mjs", "cjs", "tsx", "cts", "css", "scss", "sass", "html", "htm", "lua",
                "vim", "swift", "go", "rs", "zig", "c", "h", "cpp", "hpp", "cc", "cxx",
                "hh", "hxx", "ipp", "m", "mm", "java", "kt", "kts", "cs", "fs", "dart",
                "scala", "clj", "cljs", "cljc", "ex", "exs", "erl", "hrl", "hs", "jl",
                "r", "R", "sql", "vue", "svelte", "astro", "graphql", "gql", "proto",
                "tf", "tfvars", "hcl", "nix", "nu", "just", "make", "mk", "applescript",
                "bats", "awk", "sed", "groovy", "gradle", "qml", "cmake", "cmake.in",
                "bzl", "bazel", "star", "cue", "dhall", "elm", "gleam", "ml", "mli",
                "nim", "vala", "vapi", "wat", "pug", "haml", "slim", "erb", "ejs",
                "hbs", "handlebars", "liquid", "mustache",
            ],
            stableTypes: [
                stable("public.source-code", "Generic source code", []),
                stable("public.script", "Generic scripts", []),
                stable("public.shell-script", "Shell script", ["sh"]),
                stable("public.zsh-script", "Zsh script", ["zsh"]),
                stable("public.bash-script", "Bash script", ["bash"]),
                stable("public.python-script", "Python script", ["py"]),
                stable("public.ruby-script", "Ruby script", ["rb"]),
                stable("public.perl-script", "Perl script", ["pl"]),
                stable("public.php-script", "PHP script", ["php"]),
                stable("com.netscape.javascript-source", "JavaScript source", ["js"]),
                stable("public.css", "CSS", ["css"]),
                stable("public.html", "HTML", ["html", "htm"]),
                stable("public.swift-source", "Swift source", ["swift"]),
                stable("public.c-source", "C source", ["c"]),
                stable("public.c-header", "C header", ["h"]),
                stable("public.c-plus-plus-source", "C++ source", ["cpp", "cc", "cxx"]),
                stable("public.c-plus-plus-header", "C++ header", ["hpp", "hh", "hxx", "ipp"]),
                stable("public.objective-c-source", "Objective-C source", ["m"]),
                stable("public.objective-c-plus-plus-source", "Objective-C++ source", ["mm"]),
                stable("com.sun.java-source", "Java source", ["java"]),
                stable("com.microsoft.typescript", "TSX source", ["tsx"]),
                stable("public.protobuf-source", "Protocol Buffer source", ["proto"]),
                stable("org.iso.sql", "SQL", ["sql"]),
                stable("public.make-source", "Make source", ["make", "mk"]),
                stable("com.apple.applescript.text", "AppleScript source", ["applescript"]),
            ],
            exportedTypes: [
                exported("fish", "Fish script", ["fish"], scriptConformance),
                exported("ps1", "PowerShell script", ["ps1"], scriptConformance),
                exported("jsx", "JSX source", ["jsx"], sourceConformance),
                exported("mjs", "JavaScript module source", ["mjs"], sourceConformance),
                exported("cjs", "CommonJS source", ["cjs"], sourceConformance),
                exported("tsx", "TSX source", ["tsx"], sourceConformance),
                exported("cts", "TypeScript CommonJS source", ["cts"], sourceConformance),
                exported("scss", "SCSS source", ["scss"], sourceConformance),
                exported("sass", "Sass source", ["sass"], sourceConformance),
                exported("lua", "Lua source", ["lua"], sourceConformance),
                exported("vim", "Vim script", ["vim"], scriptConformance),
                exported("go", "Go source", ["go"], sourceConformance),
                exported("rs", "Rust source", ["rs"], sourceConformance),
                exported("zig", "Zig source", ["zig"], sourceConformance),
                exported("kt", "Kotlin source", ["kt", "kts"], sourceConformance),
                exported("cs", "C# source", ["cs"], sourceConformance),
                exported("fs", "F# source", ["fs"], sourceConformance),
                exported("dart", "Dart source", ["dart"], sourceConformance),
                exported("scala", "Scala source", ["scala"], sourceConformance),
                exported("clj", "Clojure source", ["clj", "cljs", "cljc"], sourceConformance),
                exported("ex", "Elixir source", ["ex", "exs"], sourceConformance),
                exported("erl", "Erlang source", ["erl", "hrl"], sourceConformance),
                exported("hs", "Haskell source", ["hs"], sourceConformance),
                exported("jl", "Julia source", ["jl"], sourceConformance),
                exported("r", "R source", ["r", "R"], sourceConformance),
                exported("vue", "Vue component", ["vue"], sourceConformance),
                exported("svelte", "Svelte component", ["svelte"], sourceConformance),
                exported("astro", "Astro component", ["astro"], sourceConformance),
                exported("graphql", "GraphQL document", ["graphql", "gql"], sourceConformance),
                exported("proto", "Protocol Buffer schema", ["proto"], sourceConformance),
                exported("tf", "Terraform source", ["tf", "tfvars"], sourceConformance),
                exported("hcl", "HCL source", ["hcl"], sourceConformance),
                exported("nix", "Nix source", ["nix"], sourceConformance),
                exported("nu", "Nushell source", ["nu"], scriptConformance),
                exported("just", "Justfile source", ["just"], sourceConformance),
                exported("bats", "Bats test script", ["bats"], scriptConformance),
                exported("awk", "AWK script", ["awk"], scriptConformance),
                exported("sed", "sed script", ["sed"], scriptConformance),
                exported("groovy", "Groovy source", ["groovy", "gradle"], sourceConformance),
                exported("qml", "QML source", ["qml"], sourceConformance),
                exported("cmake", "CMake source", ["cmake", "cmake.in"], sourceConformance),
                exported("bazel", "Bazel source", ["bzl", "bazel", "star"], sourceConformance),
                exported("cue", "Cue source", ["cue"], sourceConformance),
                exported("dhall", "Dhall source", ["dhall"], sourceConformance),
                exported("elm", "Elm source", ["elm"], sourceConformance),
                exported("gleam", "Gleam source", ["gleam"], sourceConformance),
                exported("ocaml", "OCaml source", ["ml", "mli"], sourceConformance),
                exported("nim", "Nim source", ["nim"], sourceConformance),
                exported("vala", "Vala source", ["vala", "vapi"], sourceConformance),
                exported("wat", "WebAssembly text", ["wat"], sourceConformance),
                exported("pug", "Pug template", ["pug"], sourceConformance),
                exported("haml", "Haml template", ["haml"], sourceConformance),
                exported("slim", "Slim template", ["slim"], sourceConformance),
                exported("erb", "ERB template", ["erb"], sourceConformance),
                exported("ejs", "EJS template", ["ejs"], sourceConformance),
                exported("handlebars", "Handlebars template", ["hbs", "handlebars"], sourceConformance),
                exported("liquid", "Liquid template", ["liquid"], sourceConformance),
                exported("mustache", "Mustache template", ["mustache"], sourceConformance),
            ]
        ),
    ]

    public static var allExtensions: [String] {
        groups.flatMap(\.extensions)
    }

    public static var allContentTypes: [String] {
        uniqued(groups.flatMap(\.contentTypes))
    }

    public static var exportedTypes: [ExportedTypeDefinition] {
        groups.flatMap(\.exportedTypes)
    }

    public static var fileTypeChoices: [FileTypeChoice] {
        groups.flatMap(\.fileTypeChoices)
    }

    public static var sampleExtensions: [String] {
        ["md", "mdx", "prompt", "json", "ndjson", "env", "dockerignore", "sh", "py", "tsx", "cts"]
    }

    public static func group(with id: FileTypeGroupID) -> FileTypeGroup? {
        groups.first { $0.id == id }
    }

    public static func group(withRawValue rawValue: String) -> FileTypeGroup? {
        guard let id = FileTypeGroupID(rawValue: rawValue) else {
            return nil
        }
        return group(with: id)
    }

    public static func selectedGroups(from identifiers: [String]) -> [FileTypeGroup] {
        if identifiers.isEmpty || identifiers.contains("all") {
            return groups
        }

        return identifiers.compactMap { group(withRawValue: $0) }
    }

    private static func exported(
        _ suffix: String,
        _ description: String,
        _ extensions: [String],
        _ conformsTo: [String]
    ) -> ExportedTypeDefinition {
        ExportedTypeDefinition(
            identifier: "\(AppConstants.bundleIdentifier).\(suffix)",
            description: description,
            extensions: extensions,
            conformsTo: conformsTo
        )
    }

    private static func stable(
        _ identifier: String,
        _ description: String,
        _ extensions: [String]
    ) -> FileTypeContentDefinition {
        FileTypeContentDefinition(
            identifier: identifier,
            description: description,
            extensions: extensions
        )
    }

    private static func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }
}
