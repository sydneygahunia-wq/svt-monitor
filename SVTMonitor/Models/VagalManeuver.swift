import Foundation

/// Reminders of vagal maneuvers, shown inside Calm Mode.
///
/// Important framing, and the reason this type carries a `precondition` field:
/// the app is **not** teaching these. Vagal maneuvers are something a
/// cardiologist decides is appropriate for a particular person and shows them
/// how to do safely. All this screen does is remind someone mid-episode of what
/// they were already taught, when recall is hardest. Anything the user has not
/// been taught, they should skip.
struct VagalManeuver: Identifiable, Equatable {
    let id: String
    let title: String
    /// One-line summary of the technique.
    let summary: String
    /// Ordered reminder steps.
    let steps: [String]
    /// The condition under which this is appropriate at all.
    let precondition: String
    let systemImage: String

    static let modifiedValsalva = VagalManeuver(
        id: "modified-valsalva",
        title: "Modified Valsalva",
        summary: "Bear down while sitting, then lie back with your legs raised.",
        steps: [
            "Sit down somewhere safe before you start.",
            "Take a breath in and bear down as if straining, for about 15 seconds.",
            "Lie back and have someone raise your legs for around 45 seconds.",
            "Rest afterwards and check whether your rate has settled."
        ],
        precondition: "Only if your cardiologist has taught you this version.",
        systemImage: "figure.flexibility"
    )

    static let valsalva = VagalManeuver(
        id: "valsalva",
        title: "Valsalva (bearing down)",
        summary: "Bear down against a closed airway for a short count.",
        steps: [
            "Sit or lie down first — never do this standing up.",
            "Take a breath in, close your mouth, and bear down as if straining.",
            "Hold for about 10 to 15 seconds, then release and breathe normally.",
            "Wait a moment before deciding whether to try again."
        ],
        precondition: "Only if you have been shown how, and only seated or lying down.",
        systemImage: "arrow.down.circle"
    )

    static let coldWater = VagalManeuver(
        id: "cold-water",
        title: "Cold on the face",
        summary: "Cold water or a cold pack against the face.",
        steps: [
            "Sit down near a sink, or hold a cold pack ready.",
            "Splash cold water on your face, or hold the cold pack against your cheeks and forehead.",
            "Keep breathing — do not hold your breath underwater.",
            "Give it a few moments before trying anything else."
        ],
        precondition: "Skip this if you have been told to avoid cold exposure.",
        systemImage: "snowflake"
    )

    static let cough = VagalManeuver(
        id: "cough",
        title: "Forceful cough",
        summary: "A few strong, deliberate coughs while seated.",
        steps: [
            "Sit down somewhere stable.",
            "Give a few firm, deliberate coughs.",
            "Pause and breathe normally in between.",
            "Stop if it makes you feel worse or more breathless."
        ],
        precondition: "Only if this is something your care team has suggested for you.",
        systemImage: "wind"
    )

    static let all: [VagalManeuver] = [.modifiedValsalva, .valsalva, .coldWater, .cough]

    /// Shown above the list, every time. Not dismissible by design.
    static let disclaimer = """
        These are reminders, not instructions. Only use a maneuver your own \
        care team has taught you, and follow their guidance over anything here. \
        Sit or lie down first. Stop straight away if you feel worse.
        """

    /// Self-administered carotid sinus massage is genuinely unsafe and is
    /// called out explicitly rather than silently omitted.
    static let neverDoAlone = """
        Never press on your own neck to try to slow your heart. Carotid massage \
        is only ever done by a clinician with monitoring in place.
        """

    /// Urgent-care guidance, shown alongside the maneuvers.
    static let seekHelpPoints: [String] = [
        "Chest pain or pressure that does not ease",
        "Fainting, or feeling like you are about to faint",
        "Severe shortness of breath",
        "An episode that lasts longer than your care team told you to wait out",
        "Anything that feels different or worse than your usual episodes"
    ]

    static let seekHelpFooter = """
        If any of these happen, call emergency services. Do not wait for the \
        episode to pass on its own, and do not drive yourself.
        """
}
