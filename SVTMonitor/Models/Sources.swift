import Foundation

/// Where the app's health guidance comes from. Shown in Settings › Sources and
/// mirrored in the README, so every claim on screen can be traced.
struct HealthSource: Identifiable {
    let id: String
    /// What in the app this source backs.
    let usedFor: String
    let title: String
    let publisher: String
    let url: URL

    static let all: [HealthSource] = [
        HealthSource(
            id: "mayo-svt",
            usedFor: "Typical SVT rates (about 150 to 220), sudden start and stop, symptoms, and when an undiagnosed fast heartbeat needs emergency care",
            title: "Supraventricular tachycardia: symptoms and causes",
            publisher: "Mayo Clinic",
            url: URL(string: "https://www.mayoclinic.org/diseases-conditions/supraventricular-tachycardia/symptoms-causes/syc-20355243")!
        ),
        HealthSource(
            id: "nhs-svt",
            usedFor: "When to call emergency services, and not driving yourself",
            title: "Supraventricular tachycardia (SVT)",
            publisher: "NHS",
            url: URL(string: "https://www.nhs.uk/conditions/supraventricular-tachycardia-svt/")!
        ),
        HealthSource(
            id: "revert",
            usedFor: "Modified Valsalva steps and timings, and standard Valsalva strain length",
            title: "Postural modification to the standard Valsalva manoeuvre for emergency treatment of supraventricular tachycardias (REVERT)",
            publisher: "The Lancet, 2015",
            url: URL(string: "https://doi.org/10.1016/S0140-6736(15)61485-4")!
        ),
        HealthSource(
            id: "healthlinkbc-vagal",
            usedFor: "Bearing down, a cold wet towel on the face, coughing, and carotid massage being for doctors only",
            title: "Vagal manoeuvres for supraventricular tachycardia",
            publisher: "HealthLink BC",
            url: URL(string: "https://www.healthlinkbc.ca/Node/4413")!
        ),
        HealthSource(
            id: "laborde-breathing",
            usedFor: "Slow breathing increasing heart rate variability, the basis for the paced breathing guide",
            title: "Effects of voluntary slow breathing on heart rate and heart rate variability: a systematic review and meta-analysis",
            publisher: "Neuroscience & Biobehavioral Reviews, 2022",
            url: URL(string: "https://doi.org/10.1016/j.neubiorev.2022.104711")!
        ),
        HealthSource(
            id: "apple-hr",
            usedFor: "Apple Watch measuring heart rate periodically in the background, not continuously",
            title: "Monitor your heart rate with Apple Watch",
            publisher: "Apple Support",
            url: URL(string: "https://support.apple.com/en-us/120277")!
        )
    ]
}
