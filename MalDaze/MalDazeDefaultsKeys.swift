import Foundation

enum MalDazeDefaultsKeys {
    enum SmartInput {
        static let llmProvider = "MalDaze.smartInput.llmProvider"
        static let llmModel = "MalDaze.smartInput.llmModel"
        static let geminiAPIKey = "MalDaze.smartInput.geminiAPIKey"
        static let openAIAPIKey = "MalDaze.smartInput.openAIAPIKey"
        static let deepSeekAPIKey = "MalDaze.smartInput.deepSeekAPIKey"
    }

    enum LegacyGemini {
        static let apiKey = "MalDaze.geminiAPIKey"
        static let modelId = "MalDaze.geminiModelId"
    }

    enum Shortcuts {
        enum DeskPetMenu {
            static let keyCode = "MalDaze.deskPetMenuShortcut.keyCode"
            static let modifiers = "MalDaze.deskPetMenuShortcut.modifiers"
            static let keyLabel = "MalDaze.deskPetMenuShortcut.keyLabel"
        }

        enum SmartReminderInput {
            static let keyCode = "MalDaze.smartReminderInputShortcut.keyCode"
            static let modifiers = "MalDaze.smartReminderInputShortcut.modifiers"
            static let keyLabel = "MalDaze.smartReminderInputShortcut.keyLabel"
        }

        enum SevenMinuteReminder {
            static let keyCode = "MalDaze.sevenMinuteReminderShortcut.keyCode"
            static let modifiers = "MalDaze.sevenMinuteReminderShortcut.modifiers"
            static let keyLabel = "MalDaze.sevenMinuteReminderShortcut.keyLabel"
        }

        enum ResetIdlePet {
            static let keyCode = "MalDaze.resetIdlePetShortcut.keyCode"
            static let modifiers = "MalDaze.resetIdlePetShortcut.modifiers"
            static let keyLabel = "MalDaze.resetIdlePetShortcut.keyLabel"
        }
    }

    enum Timer {
        static let workDurationMinutes = "MalDaze.pomodoro.workDurationMinutes"
        static let restDurationMinutes = "MalDaze.pomodoro.restDurationMinutes"
        static let preferredMode = "MalDaze.timer.preferredMode"
        static let chronoSessionSnapshot = "MalDaze.timer.chronoSessionSnapshot"
        static let suspendedModeSnapshot = "MalDaze.timer.suspendedModeSnapshot"
    }

    enum SevenMinute {
        static let durationMinutes = "MalDaze.sevenMinuteReminder.durationMinutes"
    }

    enum Rest {
        static let doubleClickEndsRest = "MalDaze.restDoubleClickEndsRest"
        static let breakInterruptStyle = "MalDaze.breakInterruptStyle"
    }

    enum Hydration {
        static let enabled = "MalDaze.hydrationReminder.enabled"
        static let intervalMinutes = "MalDaze.hydrationReminder.intervalMinutes"
        static let quietHoursEnabled = "MalDaze.hydrationReminder.quietHoursEnabled"
        static let quietStartMinutes = "MalDaze.hydrationReminder.quietStartMinutes"
        static let quietResumeMinutes = "MalDaze.hydrationReminder.quietResumeMinutes"
    }

    enum T7Eject {
        static let automaticEnabled = "MalDaze.t7Eject.automaticEnabled"
        static let scheduleStartMinuteOfDay = "MalDaze.t7Eject.scheduleStartMinuteOfDay"
        static let scheduleEndMinuteOfDay = "MalDaze.t7Eject.scheduleEndMinuteOfDay"
        static let retryIntervalSeconds = "MalDaze.t7Eject.retryIntervalSeconds"
        static let lastCompletedDay = "MalDaze.t7Eject.lastCompletedDay"
    }

    enum SleepSchedule {
        static let enabled = "MalDaze.sleepSchedule.enabled"
        static let remindersEnabled = "MalDaze.sleepSchedule.remindersEnabled"
        static let lockScreenEnabled = "MalDaze.sleepSchedule.lockScreenEnabled"
        static let dismissOnClamshell = "MalDaze.sleepSchedule.dismissOnClamshell"
        static let showerReminderEnabled = "MalDaze.sleepSchedule.showerReminderEnabled"
        static let firedContractUpdatedAt = "MalDaze.sleepSchedule.firedContractUpdatedAt"
        static let firedEventIDs = "MalDaze.sleepSchedule.firedEventIDs"
    }

    enum PetAppearance {
        static let idlePetIconAnimationEnabled = "MalDaze.idlePetIconAnimationEnabled"
        static let idlePetAnimationIntensity = "MalDaze.idlePetAnimationIntensity"
        static let idlePetIconSidePoints = "MalDaze.idlePetIconSidePoints"
    }

    enum DashboardWindow {
        static let originX = "MalDaze.dashboardWindowOriginX"
        static let originY = "MalDaze.dashboardWindowOriginY"
        static let width = "MalDaze.dashboardWindowWidth"
        static let height = "MalDaze.dashboardWindowHeight"
        static let frameUsesTitledOuterSize = "MalDaze.dashboardWindowFrameUsesTitledOuterSize"
    }

    enum DashboardLayout {
        static let leftColumnWidth = "MalDaze.dashboard.leftColumnWidth"
        static let rightColumnWidth = "MalDaze.dashboard.rightColumnWidth"
        static let leftPlanFraction = "MalDaze.dashboard.leftPlanFraction"
        /// 饮食面板「现在可以吃」区块是否展开。
        static let nutritionRecommendationExpanded = "MalDaze.dashboard.nutritionRecommendationExpanded"
        /// 饮食面板「今日额度」计算明细是否展开。
        static let nutritionTargetBreakdownExpanded = "MalDaze.dashboard.nutritionTargetBreakdownExpanded"
    }

    enum Learning {
        static let todayGrouping = "MalDaze.learning.todayGrouping"
        static let dailyCapacityHours = "MalDaze.learning.dailyCapacityHours"
        static let todayHermesTaskFraction = "MalDaze.learning.todayHermesTaskFraction"
    }
}
