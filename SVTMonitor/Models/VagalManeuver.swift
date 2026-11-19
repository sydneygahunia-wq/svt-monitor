import Foundation

/// Reminders of vagal maneuvers, shown inside Calm Mode.
///
/// Important framing, and the reason this type carries a `precondition` field:
/// the app is **not** teaching these. Vagal maneuvers are something a
/// cardiologist decides is appropriate for a particular person and shows them
/// how to do safely. All this screen does is remind someone mid-episode of what
/// they were already taught, when recall is hardest. Anything the user has not
/// been taught, they should skip.
///
/// Sources for each step are listed in `Sources.swift` and the README.
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
        summary: "Strain while propped up, then lie flat with your legs raised.",
        // Timings follow the REVERT trial (Appelboam et al., Lancet 2015):
        // 15 s strain semi-reclined, 15 s flat with legs raised, then 45 s
        // back in the semi-reclined position before checking the rhythm.
        steps: [
            "Sit propped up at about 45 degrees, on a bed or sofa.",
            "Breathe in, then strain hard for 15 seconds, as if blowing into a blocked straw.",
            "Straight away, lie flat while someone lifts your legs to about 45 degrees, for 15 seconds.",
            "Return to sitting propped up for 45 seconds, then check your heart rate."
        ],
        precondition: "Only if your cardiologist has taught you this version.",
        systemImage: "figure.flexibility"
    )

    static let valsalva = VagalManeuver(
        id: "valsalva",
        title: "Valsalva (bearing down)",
        summary: "Bear down against a closed airway for a short count.",
        steps: [
            "Sit propped up or lie down first. Never do this standing.",
            "Breathe in, close your mouth, and bear down as if straining.",
            "Hold for about 15 seconds, then release and breathe normally.",
            "Wait a moment before deciding whether to try again."
        ],
        precondition: "Only if you have been shown how, and only seated or lying down.",
        systemImage: "arrow.down.circle"
    )

    static let coldWater = VagalManeuver(
        id: "cold-water",
        title: "Cold on the face",
        summary: "An ice-cold, wet towel held against the face.",
        steps: [
            "Sit down and soak a towel or cloth in ice-cold water.",
            "Hold it against your forehead, eyes and cheeks.",
            "Keep it there briefly, then take it away and breathe normally.",
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
        "Chest pain",
        "Feeling faint, or fainting",
        "Shortness of breath",
        "An episode that lasts longer than your usual ones",
        "A very fast heartbeat for more than a few minutes, if you haven't been diagnosed with SVT"
    ]

    static let seekHelpFooter = """
        If any of these happen, call emergency services. Do not wait for the \
        episode to pass on its own, and do not drive yourself.
        """
}
