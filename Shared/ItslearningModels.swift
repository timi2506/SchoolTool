import Foundation
import SwiftUI
#if os(iOS)
import AuthenticationServices
#endif

// MARK: - itslearningToken

struct itslearningToken: Codable, Hashable {
    static let spoof = itslearningToken(
        accessToken: "abc", tokenType: "Bearer",
        refreshToken: "abc", expiry: Date().addingTimeInterval(100)
    )
    private init(accessToken: String, tokenType: String, refreshToken: String, expiry: Date) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.refreshToken = refreshToken
        self.expiry = expiry
    }
    init(from data: Data) throws {
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DecodableToken.self, from: data)
        self = itslearningToken(from: decoded)
    }
    private init(from decodableToken: DecodableToken) {
        self.accessToken = decodableToken.accessToken
        self.tokenType = decodableToken.tokenType
        self.refreshToken = decodableToken.refreshToken
        self.expiry = Date().addingTimeInterval(decodableToken.expiresIn)
    }
    var accessToken: String
    var tokenType: String
    var refreshToken: String
    var expiry: Date
    private struct DecodableToken: Decodable {
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
        var accessToken: String
        var tokenType: String
        var expiresIn: TimeInterval
        var refreshToken: String
    }
}

// MARK: - itslearningOAuthResponse

struct itslearningOAuthResponse: Codable, Hashable {
    init?(from url: URL) {
        guard url.scheme == "itsl-itslearning" else { return nil }
        let components = URLComponents(string: url.absoluteString)
        let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
        let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
        guard let code, let state else { return nil }
        self.code = code
        self.state = state
    }
    var code: String
    var state: String
}

// MARK: - PresentationContext

#if os(iOS)
final class PresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
#endif

// MARK: - itslearningPerson

struct itslearningPerson: Codable, Identifiable, Hashable {
    init(from data: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(Self.self, from: data)
    }
    static let spoof = itslearningPerson(
        id: -1, firstName: "Max", lastName: "Mustermann", language: "de",
        profileImageURL: "https://example.com/", iCalURL: "webCal://123",
        canAccessMessageSystem: true, canAccessCalendar: true,
        canAccessPersonalSettings: true, canAccessInstantMessageSystem: true,
        timeZoneID: "unknown", uses12HourTimeFormat: false, syncKey: "abc",
        canAccessCourses: true, iCalFavoritesOnlyURL: "webCal://123",
        hasHigherEducationLanguage: true, fullName: "Mustermann, Max"
    )
    private init(
        id: Int, firstName: String, lastName: String, language: String,
        profileImageURL: String, iCalURL: String, canAccessMessageSystem: Bool,
        canAccessCalendar: Bool, canAccessPersonalSettings: Bool,
        canAccessInstantMessageSystem: Bool, timeZoneID: String,
        uses12HourTimeFormat: Bool, syncKey: String, canAccessCourses: Bool,
        iCalFavoritesOnlyURL: String, hasHigherEducationLanguage: Bool, fullName: String
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.language = language
        self.profileImageURL = profileImageURL
        self.iCalURL = iCalURL
        self.canAccessMessageSystem = canAccessMessageSystem
        self.canAccessCalendar = canAccessCalendar
        self.canAccessPersonalSettings = canAccessPersonalSettings
        self.canAccessInstantMessageSystem = canAccessInstantMessageSystem
        self.timeZoneID = timeZoneID
        self.uses12HourTimeFormat = uses12HourTimeFormat
        self.syncKey = syncKey
        self.canAccessCourses = canAccessCourses
        self.iCalFavoritesOnlyURL = iCalFavoritesOnlyURL
        self.hasHigherEducationLanguage = hasHigherEducationLanguage
        self.fullName = fullName
    }
    static let unknown = Self(
        id: -1, firstName: "Unknown", lastName: "User", language: "en",
        profileImageURL: "https://example.com/", iCalURL: "https://example.com/",
        canAccessMessageSystem: true, canAccessCalendar: true,
        canAccessPersonalSettings: true, canAccessInstantMessageSystem: true,
        timeZoneID: "1", uses12HourTimeFormat: false, syncKey: "0",
        canAccessCourses: true, iCalFavoritesOnlyURL: "https://example.com/",
        hasHigherEducationLanguage: true, fullName: "Unknown User"
    )
    var id: Int
    var firstName: String
    var lastName: String
    var language: String
    var profileImageURL: String
    var iCalURL: String
    var canAccessMessageSystem: Bool
    var canAccessCalendar: Bool
    var canAccessPersonalSettings: Bool
    var canAccessInstantMessageSystem: Bool
    var timeZoneID: String
    var uses12HourTimeFormat: Bool
    var syncKey: String
    var canAccessCourses: Bool
    var iCalFavoritesOnlyURL: String
    var hasHigherEducationLanguage: Bool
    var fullName: String

    enum CodingKeys: String, CodingKey {
        case id = "PersonId"
        case firstName = "FirstName"
        case lastName = "LastName"
        case language = "Language"
        case profileImageURL = "ProfileImageUrl"
        case iCalURL = "iCalUrl"
        case canAccessMessageSystem = "CanAccessMessageSystem"
        case canAccessCalendar = "CanAccessCalendar"
        case canAccessPersonalSettings = "CanAccessPersonalSettings"
        case canAccessInstantMessageSystem = "CanAccessInstantMessageSystem"
        case timeZoneID = "TimeZoneId"
        case uses12HourTimeFormat = "Use12HTimeFormat"
        case syncKey = "SyncKey"
        case canAccessCourses = "CanAccessCourses"
        case iCalFavoritesOnlyURL = "iCalFavoriteOnlyUrl"
        case hasHigherEducationLanguage = "HasHigherEducationLanguage"
        case fullName = "FullName"
    }
}

// MARK: - AllSitesQuery

struct AllSitesQuery: Codable {
    init() async throws {
        let request = URLRequest(url: URL(string: "https://itslearning.itslearning.com/restapi/sites/all/v1/")!)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(Self.self, from: data)
        self = decoded
    }
    var allSites: [itslearningSite]
    var total: Int
    var currentPageIndex: Int
    var pageSize: Int
    enum CodingKeys: String, CodingKey {
        case allSites = "EntityArray"
        case total = "Total"
        case currentPageIndex = "CurrentPageIndex"
        case pageSize = "PageSize"
    }
    struct itslearningSite: Codable, Identifiable, Hashable {
        let customerId: Int
        let title: String
        let shortName: String
        let cultureName: String
        let baseUrl: String
        let isPersonalRestApiEnabled: Bool
        let showCustomerInDropdownList: Bool
        let countryCode: String
        let stateCode: String

        var id: Int { customerId }

        enum CodingKeys: String, CodingKey {
            case customerId = "CustomerId"
            case title = "Title"
            case shortName = "ShortName"
            case cultureName = "CultureName"
            case baseUrl = "BaseUrl"
            case isPersonalRestApiEnabled = "IsPersonalRestApiEnabled"
            case showCustomerInDropdownList = "ShowCustomerInDropdownList"
            case countryCode = "CountryCode"
            case stateCode = "StateCode"
        }
    }
}

// MARK: - AllCoursesQuery

struct AllCoursesQuery: Codable {
    init(from data: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(Self.self, from: data)
    }
    var courses: [itslearningCourse]
    var total: Int
    var currentPageIndex: Int
    var pageSize: Int

    enum CodingKeys: String, CodingKey {
        case courses = "EntityArray"
        case total = "Total"
        case currentPageIndex = "CurrentPageIndex"
        case pageSize = "PageSize"
    }
    struct itslearningCourse: Codable, Identifiable {
        var lastUpdated: String
        var newNotificationsCount: Int
        var newBulletinsCount: Int
        var url: URL
        var hasAdminPermissions: Bool
        var hasStudentPermissions: Bool
        var id: Int
        var title: String
        var friendlyName: String?
        var color: String
        var fillColor: String
        var code: String

        enum CodingKeys: String, CodingKey {
            case lastUpdated = "LastUpdatedUtc"
            case newNotificationsCount = "NewNotificationsCount"
            case newBulletinsCount = "NewBulletinsCount"
            case url = "Url"
            case hasAdminPermissions = "HasAdminPermissions"
            case hasStudentPermissions = "HasStudentPermissions"
            case id = "CourseId"
            case title = "Title"
            case friendlyName = "FriendlyName"
            case color = "CourseColor"
            case fillColor = "CourseFillColor"
            case code = "CourseCode"
        }
    }
}

// MARK: - NotificationsQuery

struct NotificationsQuery: Codable {
    init(from data: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(Self.self, from: data)
    }
    var notifications: [NotificationItem]
    var total: Int
    var currentPageIndex: Int
    var pageSize: Int

    enum CodingKeys: String, CodingKey {
        case notifications = "EntityArray"
        case total = "Total"
        case currentPageIndex = "CurrentPageIndex"
        case pageSize = "PageSize"
    }
    struct NotificationItem: Codable, Identifiable {
        var id: Int
        var text: String
        var publishedDate: String
        var publishedBy: PublishedBy
        var type: String
        var url: String
        var contentUrl: String
        var isRead: Bool
        var isAnonymous: Bool

        enum CodingKeys: String, CodingKey {
            case id = "NotificationId"
            case text = "Text"
            case publishedDate = "PublishedDate"
            case publishedBy = "PublishedBy"
            case type = "Type"
            case url = "Url"
            case contentUrl = "ContentUrl"
            case isRead = "IsRead"
            case isAnonymous = "IsAnonymous"
        }
    }
    struct PublishedBy: Codable {
        var personId: Int
        var firstName: String
        var lastName: String
        var fullName: String
        var profileUrl: String?
        var additionalInfo: String?
        var profileImageUrl: String?
        var profileImageUrlSmall: String?

        enum CodingKeys: String, CodingKey {
            case personId = "PersonId"
            case firstName = "FirstName"
            case lastName = "LastName"
            case fullName = "FullName"
            case profileUrl = "ProfileUrl"
            case additionalInfo = "AdditionalInfo"
            case profileImageUrl = "ProfileImageUrl"
            case profileImageUrlSmall = "ProfileImageUrlSmall"
        }
    }
    struct NotificationUpdate: Encodable {
        var id: Int
        var isRead: Bool
        enum CodingKeys: String, CodingKey {
            case id = "NotificationId"
            case isRead = "IsRead"
        }
    }
}

// MARK: - itslearningMessage

struct itslearningMessage: Codable, Identifiable {
    var id: Int
}

struct itslearningMessageToSend: Encodable {
    var to: [itslearningPerson.ID]
    var bcc: [itslearningPerson.ID]
    var replyTo: itslearningMessage.ID?
    var forwardOf: itslearningMessage.ID?
    var subject: String
    var text: String
    enum CodingKeys: String, CodingKey {
        case to = "ToPersonIds"
        case bcc = "BccPersonIds"
        case replyTo = "ReplyToMessageId"
        case forwardOf = "ForwardToMessageId"
        case subject = "Subject"
        case text = "Text"
    }
}
