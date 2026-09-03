// Deliberately no `import Foundation` here — see Support.swift.
import Testing
@testable import AIUsageBarCore

@Test func addsTheSectionWhenAbsent() {
    let out = ConfigEditor.setOpenCodeGoKey(in: "[ui]\nx = 1\n", key: "abc")
    #expect(out == "[ui]\nx = 1\n\n[opencode-go]\nenabled = true\napi_key = \"abc\"\n")
}

@Test func addsTheSectionToAnEmptyFile() {
    let out = ConfigEditor.setOpenCodeGoKey(in: "", key: "abc")
    #expect(out == "[opencode-go]\nenabled = true\napi_key = \"abc\"\n")
}

@Test func fillsAnExistingSectionThatHasNoKey() {
    let out = ConfigEditor.setOpenCodeGoKey(
        in: "[opencode-go]\napi_key_env = \"OPENCODE_GO_API_KEY\"\n\n[zai]\nenabled = false\n",
        key: "abc"
    )
    #expect(out == """
    [opencode-go]
    enabled = true
    api_key = "abc"
    api_key_env = "OPENCODE_GO_API_KEY"

    [zai]
    enabled = false

    """)
}

@Test func replacesAnExistingKeyAndEnablesTheVendor() {
    let out = ConfigEditor.setOpenCodeGoKey(
        in: "[opencode-go]\nenabled = false\napi_key = \"old\"\n\n[zai]\nenabled = false\n",
        key: "new"
    )
    #expect(out == """
    [opencode-go]
    enabled = true
    api_key = "new"

    [zai]
    enabled = false

    """)
}

@Test func leavesLaterSectionsUntouched() {
    let out = ConfigEditor.setOpenCodeGoKey(in: "[opencode-go]\n\n[zai]\napi_key = \"keep\"\n", key: "abc")
    #expect(out.contains("[zai]\napi_key = \"keep\""))
}

@Test func escapesQuotesAndBackslashes() {
    let out = ConfigEditor.setOpenCodeGoKey(in: "", key: #"a"b\c"#)
    #expect(out.contains(#"api_key = "a\"b\\c""#))
}
