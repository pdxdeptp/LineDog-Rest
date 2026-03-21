import XCTest
@testable import LineDog

final class SmartReminderNotesComposerTests: XCTestCase {
    func testRoutineAppendsTagWhenNotesEmpty() {
        XCTAssertEqual(
            SmartReminderNotesComposer.finalizedNotes(llmNotes: nil, isRoutine: true),
            "#日常"
        )
    }

    func testRoutineAppendsTagWhenNotesPresent() {
        XCTAssertEqual(
            SmartReminderNotesComposer.finalizedNotes(llmNotes: "饭前吃", isRoutine: true),
            "饭前吃\n#日常"
        )
    }

    func testRoutineDoesNotDuplicateTag() {
        XCTAssertEqual(
            SmartReminderNotesComposer.finalizedNotes(llmNotes: "x\n#日常", isRoutine: true),
            "x\n#日常"
        )
    }

    func testNonRoutinePassesNotesThrough() {
        XCTAssertEqual(
            SmartReminderNotesComposer.finalizedNotes(llmNotes: "备注", isRoutine: false),
            "备注"
        )
    }

    func testNonRoutineNilNotesStaysNil() {
        XCTAssertNil(SmartReminderNotesComposer.finalizedNotes(llmNotes: nil, isRoutine: false))
    }

    func testRoutineInferenceLLMTrue() {
        XCTAssertTrue(
            SmartReminderRoutineInference.effectiveIsRoutine(
                llm: true,
                rawUserInput: "随便",
                reminderTitle: "x"
            )
        )
    }

    func testRoutineInferenceChoreInUserText() {
        XCTAssertTrue(
            SmartReminderRoutineInference.effectiveIsRoutine(
                llm: false,
                rawUserInput: "记得洗碗",
                reminderTitle: "提醒"
            )
        )
    }

    func testRoutineInferenceHashMarkerInTitle() {
        XCTAssertTrue(
            SmartReminderRoutineInference.effectiveIsRoutine(
                llm: false,
                rawUserInput: "x",
                reminderTitle: "跑步 #日常"
            )
        )
    }
}
