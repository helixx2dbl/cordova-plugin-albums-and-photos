import Foundation
import Photos
import PhotosUI
// Assuming CDVPlugin is the base class, adjust if necessary
// import Cordova // Or the specific Cordova module

// MARK: - Constants
private enum Constants {
    static let pId = "id"
    static let pName = "name"
    static let pWidth = "width"
    static let pHeight = "height"
    static let pLat = "latitude"
    static let pLon = "longitude"
    static let pDate = "date"
    static let pTs = "timestamp"
    static let pType = "contentType"
    static let pDuration = "duration"
    static let pUri = "uri"
    static let pCount = "count"
    static let pFavorited = "favorited"

    static let pSize = "dimension"
    static let pQuality = "quality"
    static let pAsDataUrl = "asDataUrl"

    static let pCMode = "collectionMode"
    static let pCModeRoll = "ROLL"
    static let pCModeSmart = "SMART"
    static let pCModeShared = "SHARED"
    static let pCModeImported = "IMPORTED"
    static let pCModeFaces = "FACES"
    static let pCModeAlbums = "ALBUMS"
    static let pCModeMoments = "MOMENTS"
    static let pCModeRecent = "RECENT"

    static let pListOffset = "offset"
    static let pListLimit = "limit"
    static let pListInterval = "interval"
    static let pSearchText = "searchText"
    static let pStartDate = "startDate"
    static let pEndDate = "endDate"

    static let tDataUrl = "data:image/jpeg;base64,%@"
    static let tDateFormat = "YYYY-MM-dd HH:mm:ss"
    static let tExtPattern = "^(.+)\\.([a-z]{3,4})$"

    static let defSize: Int = 120
    static let defQuality: Int = 80
    static let defName = "No Name"

    static let ePermission = "Access to Photo Library permission required"
    static let eCollectionMode = "Unsupported collection mode"
    static let ePhotoNoData = "Specified photo has no data"
    static let ePhotoThumb = "Cannot get a thumbnail of photo"
    static let ePhotoIdUndef = "Photo ID is undefined"
    static let ePhotoIdWrong = "Photo with specified ID wasn't found"
    static let ePhotoNotImage = "Data with specified ID isn't an image"
    static let ePhotoBusy = "Fetching of photo assets is in progress"

    static let sSortType = "creationDate"

    enum AuthorizationStatusString: String {
        case denied = "AUTHORIZATION_DENIED"
        case notDetermined = "AUTHORIZATION_NOT_DETERMINED"
        case granted = "AUTHORIZATION_GRANTED"
    }
}

@objc(CDVPhotos)
class CDVPhotos: CDVPlugin {

    private lazy var dateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = Constants.tDateFormat
        return formatter
    }()

    private lazy var extType: [String: String] = {
        // image: handler always returns JPEG bytes, so report image/jpeg for
        // formats web/JS clients are unlikely to decode natively (HEIC/HEIF/DNG).
        return [
            "JPG": "image/jpeg",
            "JPEG": "image/jpeg",
            "PNG": "image/png",
            "GIF": "image/gif",
            "TIF": "image/tiff",
            "TIFF": "image/tiff",
            "HEIC": "image/jpeg",
            "HEIF": "image/jpeg",
            "HEICS": "image/jpeg",
            "HEIFS": "image/jpeg",
            "DNG":  "image/jpeg",   // Apple ProRAW (iPhone 12 Pro+)
            "WEBP": "image/webp",
            "BMP":  "image/bmp",
            "MP4": "video/mp4",
            "MOV": "video/quicktime",
            "AVI": "video/x-msvideo",
            "MPEG": "video/mpeg",
            "MPG": "video/mpeg",
            "MPEG-4": "video/mp4",
            "M4V": "video/mp4",
            "3GP": "video/3gpp",
            "3G2": "video/3gpp2",
            "M4A": "audio/mp4",
            "AAC": "audio/mp4",
            "MP3": "audio/mp3",
            "WAV": "audio/wav",
            "WMA": "audio/x-ms-wma"
        ]
    }()

    private lazy var extRegex: NSRegularExpression? = {
        do {
            return try NSRegularExpression(pattern: Constants.tExtPattern,
                                           options: [.caseInsensitive, .dotMatchesLineSeparators, .anchorsMatchLines])
        } catch {
            print("Error creating regex: \(error)")
            return nil
        }
    }()

    // tracks the in-flight PHPickerViewController invocation so the delegate
    // callback can resolve the right cordova command
    private var pickerCommand: CDVInvokedUrlCommand?

    private var photosCommand: CDVInvokedUrlCommand?

    override func pluginInitialize() {
        super.pluginInitialize()
        // Properties are initialized lazily, so no explicit setup needed here
        // for dateFormat, extType, extRegex unless specific non-lazy init is required.
    }

    // MARK: - Helper methods for command arguments and results (to be implemented)
    private func arg<T>(of command: CDVInvokedUrlCommand, at index: Int, default defaultValue: T) -> T {
        guard let arg = command.argument(at: UInt(index)) as? T, arg as? NSNull != NSNull() else {
            return defaultValue
        }
        return arg
    }
    
    private func valueFrom<T>(dictionary: [AnyHashable: Any], byKey key: String, default defaultValue: T) -> T {
        guard let value = dictionary[key], value as? NSNull != NSNull() else {
            return defaultValue
        }

        if let typedValue = value as? T {
            return typedValue
        }

        if let number = value as? NSNumber, T.self == String.self {
            return number.stringValue as? T ?? defaultValue
        }

        return defaultValue
    }

    private func isNull(_ value: Any?) -> Bool {
        return value == nil || value is NSNull
    }
    
    // MARK: - Callback methods
    private func success(command: CDVInvokedUrlCommand) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    private func success(command: CDVInvokedUrlCommand, message: String) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: message)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }
    
    private func success(command: CDVInvokedUrlCommand, array: [Any]) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: array)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }
    
    private func success(command: CDVInvokedUrlCommand, json: [String:String]) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    private func success(command: CDVInvokedUrlCommand, data: Data) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsArrayBuffer: data)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }
    
    private func partial(command: CDVInvokedUrlCommand, array: [Any]) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: array)
        pluginResult.setKeepCallbackAs(true)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    private func failure(command: CDVInvokedUrlCommand, message: String) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: message)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }
    
    // MARK: - Permissions
    private func checkPermissions(of command: CDVInvokedUrlCommand, andRun block: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            self.commandDelegate.run { // Using commandDelegate.run to ensure it runs on a background thread if needed by Cordova
                block()
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                if newStatus == .authorized {
                    self?.commandDelegate.run {
                        block()
                    }
                } else {
                    self?.failure(command: command, message: Constants.ePermission)
                }
            }
        default:
            self.failure(command: command, message: Constants.ePermission)
        }
    }

    private func getPhotoLibraryAuthorizationStatusString() -> String {
        let authStatus = PHPhotoLibrary.authorizationStatus()
        return getPhotoLibraryAuthorizationStatusString(for: authStatus)
    }

    private func getPhotoLibraryAuthorizationStatusString(for authStatus: PHAuthorizationStatus) -> String {
        switch authStatus {
        case .denied, .restricted:
            return Constants.AuthorizationStatusString.denied.rawValue
        case .notDetermined:
            return Constants.AuthorizationStatusString.notDetermined.rawValue
        case .authorized:
            return Constants.AuthorizationStatusString.granted.rawValue
        case .limited: // iOS 14+
             return Constants.AuthorizationStatusString.granted.rawValue // Or a new "LIMITED" status if your JS expects it
        @unknown default:
            return Constants.AuthorizationStatusString.notDetermined.rawValue // Or handle appropriately
        }
    }

    @objc(getPhotoLibraryAuthorization:)
    func getPhotoLibraryAuthorization(command: CDVInvokedUrlCommand) {
        self.commandDelegate.run { [weak self] in
            guard let self = self else { return }
                let status = self.getPhotoLibraryAuthorizationStatusString()
                self.success(command: command, message: status)
        }
    }

    @objc(requestPhotoLibraryAuthorization:)
    func requestPhotoLibraryAuthorization(command: CDVInvokedUrlCommand) {
        self.commandDelegate.run { [weak self] in
            guard let self = self else { return }
                PHPhotoLibrary.requestAuthorization { [weak self] authStatus in
                    guard let self = self else { return }
                    let statusString = self.getPhotoLibraryAuthorizationStatusString(for: authStatus)
                    self.success(command: command, message: statusString)
                }
        }
    }

    // MARK: - Command Implementations
    @objc(collections:)
    func collections(command: CDVInvokedUrlCommand) {
        checkPermissions(of: command) { [weak self] in
            guard let self = self else { return }
            
            let options: [String: Any] = self.arg(of: command, at: 0, default: [:] as [String: Any])
            
            guard let fetchResultCollections = self.fetchCollections(options: options) else {
                self.failure(command: command, message: Constants.eCollectionMode)
                return
            }

            // ALBUMS mode returns top-level user collections, which mixes PHAssetCollection
            // (albums) and PHCollectionList (folders). Recurse into folders so albums nested
            // inside them get listed too — otherwise they're invisible in the picker.
            var albums: [(album: PHAssetCollection, displayName: String)] = []
            fetchResultCollections.enumerateObjects { (collection, _, _) in
                albums.append(contentsOf: self.collectAlbums(from: collection, parentPath: nil))
            }

            let result: [[String: Any]] = albums.map { item in
                let count = item.album.estimatedAssetCount
                return [
                    Constants.pId: item.album.localIdentifier,
                    Constants.pName: item.displayName,
                    Constants.pCount: "\(count)"
                ]
            }
            self.success(command: command, array: result)
        }
    }

    private func collectAlbums(from collection: PHCollection, parentPath: String?) -> [(album: PHAssetCollection, displayName: String)] {
        let title = collection.localizedTitle ?? Constants.defName
        var result: [(album: PHAssetCollection, displayName: String)] = []

        if let assetCollection = collection as? PHAssetCollection {
            if assetCollection.canContainAssets {
                var displayName = title
                if let parentPath = parentPath {
                    displayName = "\(parentPath) / \(title)"
                }
                result.append((album: assetCollection, displayName: displayName))
            }
        } else if let collectionList = collection as? PHCollectionList {
            var newPath = title
            if let parentPath = parentPath {
                newPath = "\(parentPath) / \(title)"
            }
            let children = PHCollection.fetchCollections(in: collectionList, options: nil)
            children.enumerateObjects { (child, _, _) in
                result.append(contentsOf: self.collectAlbums(from: child, parentPath: newPath))
            }
        }

        return result
    }

    // MARK: - Auxiliary functions (to be implemented or moved)
    private func fetchCollections(options: [String: Any]) -> PHFetchResult<PHCollection>? {
        let mode = valueFrom(dictionary: options, byKey: Constants.pCMode, default: Constants.pCModeRoll)
        
        if mode == Constants.pCModeRoll {
            return PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil) as? PHFetchResult<PHCollection>
        } else if mode == Constants.pCModeSmart {
            return PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil) as? PHFetchResult<PHCollection>
        } else if mode == Constants.pCModeRecent {
            return PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumRecentlyAdded, options: nil) as? PHFetchResult<PHCollection>
        } else if mode == Constants.pCModeShared {
            return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil) as? PHFetchResult<PHCollection>
        } else if mode == Constants.pCModeImported {
            return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumImported, options: nil) as? PHFetchResult<PHCollection>
        } else if mode == Constants.pCModeFaces {
            return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumSyncedFaces, options: nil) as? PHFetchResult<PHCollection>
        } else if mode == Constants.pCModeAlbums {
            return PHCollectionList.fetchTopLevelUserCollections(with: nil) as PHFetchResult<PHCollection>
        } else if mode == Constants.pCModeMoments {
            return PHAssetCollection.fetchAssetCollections(with: .moment, subtype: .any, options: nil) as? PHFetchResult<PHCollection>
        } else {
            return nil
        }
    }
    
    
    private func assetByCommand(command: CDVInvokedUrlCommand) -> PHAsset? {
        guard let assetId: String = arg(of: command, at: 0, default: nil) else {
            failure(command: command, message: Constants.ePhotoIdUndef)
            return nil
        }

        let fetchOptions = PHFetchOptions()
        // fetchOptions.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        fetchOptions.includeAllBurstAssets = true
        fetchOptions.includeHiddenAssets = true
        
        
        let fetchResultAssets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: fetchOptions)
        
        guard fetchResultAssets.count > 0 else {
            failure(command: command, message: Constants.ePhotoIdWrong)
            return nil
        }
        
        guard let asset = fetchResultAssets.firstObject else {
            // Should not happen if count > 0, but good for safety
            failure(command: command, message: Constants.ePhotoIdWrong)
            return nil
        }
        
        if asset.mediaType != .image && asset.mediaType != .video {
            failure(command: command, message: "Asset is neither an image nor a video")
            return nil
        }
        return asset
    }

    private struct AssetMeta {
        let name: String
        let ext: String       // lowercase, no leading dot
        let mimeType: String
    }

    // Resolve a (name, ext, mimeType) triple for a PHAsset that NEVER returns nil.
    // The previous KVC "filename" path silently dropped any asset where the value
    // came back nil (common for some iCloud / synced / edited assets) and any asset
    // whose extension wasn't in extType (DNG/HEIF/etc). We now use the documented
    // PHAssetResource API first, fall back to KVC, and as a last resort synthesise
    // a name from the asset id + mediaType so we never lose an asset that's there.
    private func metaForAsset(_ asset: PHAsset) -> AssetMeta {
        let resources = PHAssetResource.assetResources(for: asset)
        let primary = resources.first { r in
            r.type == .photo || r.type == .video || r.type == .audio
                || r.type == .fullSizePhoto || r.type == .fullSizeVideo
        } ?? resources.first

        var raw: String? = primary?.originalFilename
        if raw == nil || raw!.isEmpty {
            raw = asset.value(forKey: "filename") as? String
        }

        var name = ""
        var ext = ""
        if let filename = raw, !filename.isEmpty {
            let url = URL(fileURLWithPath: filename)
            name = url.deletingPathExtension().lastPathComponent
            ext = url.pathExtension.lowercased()
        }

        if name.isEmpty {
            name = asset.localIdentifier.components(separatedBy: "/").first ?? asset.localIdentifier
        }

        var mime: String? = nil
        if !ext.isEmpty {
            mime = self.extType[ext.uppercased()]
        }
        if mime == nil {
            switch asset.mediaType {
            case .image: mime = "image/jpeg"
            case .video: mime = "video/mp4"
            case .audio: mime = "audio/mp4"
            default:     mime = "application/octet-stream"
            }
        }

        if ext.isEmpty {
            switch asset.mediaType {
            case .image: ext = "jpg"
            case .video: ext = "mp4"
            case .audio: ext = "m4a"
            default:     ext = "bin"
            }
        }

        return AssetMeta(name: name, ext: ext, mimeType: mime!)
    }
    
    
    @objc(videos:)
    func videos(command: CDVInvokedUrlCommand) {
        if self.photosCommand != nil { // Shared with photos, as per original Obj-C
            self.failure(command: command, message: Constants.ePhotoBusy)
            return
        }
        self.photosCommand = command
        
        checkPermissions(of: command) { [weak self] in
            guard let self = self else {
                // As with photos method, consider implications if self is nil here.
                return
            }
            
            let collectionIds: [String]? = self.arg(of: command, at: 0, default: nil)
            let options: [String: Any] = self.arg(of: command, at: 1, default: [:] as [String: Any])
            // NSLog(@"videos: collectionIds=%@", collectionIds);
            print("videos: collectionIds=\(collectionIds ?? [])")
            
            let startDateStr: String? = self.valueFrom(dictionary: options, byKey: Constants.pStartDate, default: nil)
            let endDateStr: String? = self.valueFrom(dictionary: options, byKey: Constants.pEndDate, default: nil)
            
            // Create search predicate
            var predicates: [NSPredicate] = [NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)]
            
            // add in start / end date
            if let startDateStr = startDateStr, !startDateStr.isEmpty {
                let range = dateRangeFromUserInputs(startInput:startDateStr, endInput: endDateStr!)
                predicates.append(NSPredicate( format: "creationDate >= %@ AND creationDate < %@", range!.start as NSDate, range!.end as NSDate))
            }
            
            let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            var result: [[String: Any]]? = nil
            
            if collectionIds == nil || collectionIds!.isEmpty {
                result = self.fetchAllMedia(ofType: .video, command: command, predicate: finalPredicate)
            } else {
                let fetchResultAssetCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: collectionIds!, options: nil)
                
                if fetchResultAssetCollections.count == 0 && !collectionIds!.isEmpty {
                     print("Warning: No collections found for given IDs: \(collectionIds!)")
                }
                result = self.fetchMediaFromCollections(ofType: .video, fetchResultAssetCollections: fetchResultAssetCollections, command: command, predicate: finalPredicate)
            }
            
            self.photosCommand = nil // Clear the shared command
            if let res = result {
                self.success(command: command, array: res)
            } else {
                // This case should ideally be handled by sub-methods sending a failure
                self.failure(command: command, message: "Failed to fetch videos.")
            }
        }
    }

    

    @objc(photos:)
    func photos(command: CDVInvokedUrlCommand) {
        if self.photosCommand != nil {
            self.failure(command: command, message: Constants.ePhotoBusy)
            return
        }
        self.photosCommand = command
        
        checkPermissions(of: command) { [weak self] in
            guard let self = self else { return }
            
            let collectionIds: [String]? = self.arg(of: command, at: 0, default: nil)
            let options: [String: Any] = self.arg(of: command, at: 1, default: [:] as [String: Any])
            
            // Extract search parameters
            let searchText: String? = self.valueFrom(dictionary: options, byKey: Constants.pSearchText, default: nil)
            let startDateStr: String? = self.valueFrom(dictionary: options, byKey: Constants.pStartDate, default: nil)
            let endDateStr: String? = self.valueFrom(dictionary: options, byKey: Constants.pEndDate, default: nil)
            
            
            // Create search predicate
            var predicates: [NSPredicate] = [NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)]
            
            // add in the dates
            if let startDateStr = startDateStr, !startDateStr.isEmpty {
                let range = dateRangeFromUserInputs(startInput:startDateStr, endInput: endDateStr!)
                predicates.append(NSPredicate( format: "creationDate >= %@ AND creationDate < %@", range!.start as NSDate, range!.end as NSDate))
            }
            
            
            // Combine all predicates
            let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            var result: [[String: Any]]? = nil
            
            if collectionIds == nil || collectionIds!.isEmpty {
                result = self.fetchAllMedia(ofType: .image, command: command, predicate: finalPredicate)
            } else {
                let fetchResultAssetCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: collectionIds!, options: nil)
                
                if fetchResultAssetCollections.count == 0 && !collectionIds!.isEmpty {
                    print("Warning: No collections found for given IDs: \(collectionIds!)")
                }
                result = self.fetchMediaFromCollections(ofType: .image, fetchResultAssetCollections: fetchResultAssetCollections, command: command, predicate: finalPredicate)
            }
            
            self.photosCommand = nil
            if let res = result {
                self.success(command: command, array: res)
            } else {
                self.failure(command: command, message: "Failed to fetch photos.")
            }
        }
    }

    // presents apples native PHPickerViewController (iOS 14+) so the user can search
    // their library with apples built-in content search, faces, locations, etc., and
    // pick one or many photos. results are returned in the same dict shape as photos:
    // so the JS side can treat them like any other batch coming through onPhotosPageLoaded.
    //
    // JS shape: Photos.pickPhotos({ limit: 10, mediaType: "image" }, onSuccess, onError)
    //   limit:     0 (default) for unlimited, or N for max selections
    //   mediaType: "image" (default), "video", or "any"
    @objc(pickPhotos:)
    func pickPhotos(command: CDVInvokedUrlCommand) {
        if #available(iOS 14, *) {
            self.presentPHPicker(command: command)
        } else {
            self.failure(command: command, message: "PHPicker requires iOS 14 or newer")
        }
    }

    func dateRangeFromUserInputs(startInput: String, endInput: String) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        func parseDate(_ input: String, isEndDate: Bool = false) -> Date? {
            let cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let formats = [
                "yyyy-MM-dd",    // exact day
                "MM/dd/yyyy",    // exact day
                "MMMM d, yyyy",  // exact day
                "MMM d, yyyy",   // exact day
                "MMMM yyyy",     // month + year
                "MMM yyyy",      // month + year
                "yyyy"           // year only
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: cleanedInput.capitalized) {
                    switch format {
                    case "yyyy-MM-dd", "MM/dd/yyyy", "MMMM d, yyyy", "MMM d, yyyy":
                        return isEndDate ? calendar.date(byAdding: .day, value: 1, to: date) : date
                    case "MMMM yyyy", "MMM yyyy":
                        return isEndDate ? calendar.date(byAdding: .month, value: 1, to: date) : date
                    case "yyyy":
                        return isEndDate ? calendar.date(byAdding: .year, value: 1, to: date) : date
                    default:
                        break
                    }
                }
            }
            return nil
        }
        
        guard let startDate = parseDate(startInput), let endDate = parseDate(endInput, isEndDate: true) else {
            return nil
        }
        
        return (start: startDate, end: endDate)
    }

    // Update fetchAllMedia to accept predicate
    private func fetchAllMedia(ofType mediaType: PHAssetMediaType, command: CDVInvokedUrlCommand, predicate: NSPredicate? = nil) -> [[String: Any]]? {
        guard let currentCommand = self.photosCommand else { return nil }
        
        let options: [String: Any] = self.arg(of: currentCommand, at: 1, default: [:] as [String: Any])
        print("fetchAllMedia options: \(options)")
        let offset = valueFrom(dictionary: options, byKey: Constants.pListOffset, default: "0").toInt() ?? 0
        let limit = valueFrom(dictionary: options, byKey: Constants.pListLimit, default: "0").toInt() ?? 0

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: Constants.sSortType, ascending: false)]
        //fetchOptions.sortDescriptors = [NSSortDescriptor(key: "mediaType", ascending: false)]
        fetchOptions.includeAllBurstAssets = false
        fetchOptions.includeHiddenAssets = false
        
        let allSources: PHAssetSourceType = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        fetchOptions.includeAssetSourceTypes = allSources
        
        // Apply the search predicate if provided
        if let predicate = predicate {
            fetchOptions.predicate = predicate
        } else {
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", mediaType.rawValue)
        }
        
        // cap the fetch at offset+limit so PhotoKit doesnt materialize the whole library
        // for paged queries. previously fetchLimit was only set when offset == 0, so
        // every subsequent page enumerated unbounded
        if limit > 0 {
            fetchOptions.fetchLimit = offset + limit
        }

        let fetchResultAssets = PHAsset.fetchAssets(with: fetchOptions)


        var fetchedCount = 0
        var result: [[String: Any]] = []

        fetchResultAssets.enumerateObjects { [weak self] (asset, _, stop) in
            guard let self = self else { return }
            if self.photosCommand == nil {
                stop.pointee = true
                return
            }

            if fetchedCount >= offset {
                // metaForAsset hits asset resources for mime/ext - dont pay this cost
                // for assets below the offset that we'd just throw away
                let meta = self.metaForAsset(asset)
                var assetItem: [String: Any] = [
                    Constants.pId: asset.localIdentifier,
                    Constants.pName: meta.name,
                    Constants.pType: meta.mimeType,
                    Constants.pDate: self.dateFormat.string(from: asset.creationDate ?? Date()),
                    Constants.pTs: Int64((asset.creationDate ?? Date()).timeIntervalSince1970 * 1000),
                    Constants.pDuration: asset.duration,
                    Constants.pWidth: asset.pixelWidth,
                    Constants.pHeight: asset.pixelHeight,
                    Constants.pFavorited: asset.isFavorite
                ]

                if let location = asset.location {
                    assetItem[Constants.pLat] = location.coordinate.latitude
                    assetItem[Constants.pLon] = location.coordinate.longitude
                }

                let assetIdPathless = asset.localIdentifier.components(separatedBy: "/").first ?? ""
                let uriString = "assets-library://asset/asset.\(meta.ext)?id=\(assetIdPathless)&ext=\(meta.ext)"
                assetItem[Constants.pUri] = uriString

                result.append(assetItem)

                if limit > 0 && result.count >= limit {
                    stop.pointee = true
                    return
                }
            }
            fetchedCount += 1
        }

        return result
    }

    // Update fetchMediaFromCollections to accept predicate
    private func fetchMediaFromCollections(ofType mediaType: PHAssetMediaType, fetchResultAssetCollections: PHFetchResult<PHAssetCollection>, command: CDVInvokedUrlCommand, predicate: NSPredicate? = nil) -> [[String: Any]]? {
        guard let currentCommand = self.photosCommand else { return nil }

        let options: [String: Any] = self.arg(of: currentCommand, at: 1, default: [:] as [String: Any])
        print("fetchMediaFromCollections options: \(options)")
        let offset = valueFrom(dictionary: options, byKey: Constants.pListOffset, default: "0").toInt() ?? 0
        let limit = valueFrom(dictionary: options, byKey: Constants.pListLimit, default: "0").toInt() ?? 0
        
        var fetchedCount = 0
        var result: [[String: Any]] = []

        fetchResultAssetCollections.enumerateObjects { [weak self] (assetCollection, _, stopCollections) in
            guard let self = self else { return }
            if self.photosCommand == nil {
                stopCollections.pointee = true
                return
            }

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: Constants.sSortType, ascending: false)]
            fetchOptions.includeAllBurstAssets = false
            fetchOptions.includeHiddenAssets = false
            
            let allSources: PHAssetSourceType = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
            fetchOptions.includeAssetSourceTypes = allSources
            
            // Apply the search predicate if provided
            if let predicate = predicate {
                fetchOptions.predicate = predicate
            } else {
                fetchOptions.predicate = NSPredicate(format: "mediaType = %d", mediaType.rawValue)
            }
            
            // cap the fetch at offset+limit so PhotoKit doesnt materialize the whole
            // collection for paged queries. previously fetchLimit was only set when
            // offset == 0, so every subsequent page enumerated unbounded
            if limit > 0 {
                fetchOptions.fetchLimit = offset + limit
            }

            let fetchResultAssets = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)

            fetchResultAssets.enumerateObjects { (asset, _, stopAssets) in
                if self.photosCommand == nil {
                    stopAssets.pointee = true
                    stopCollections.pointee = true
                    return
                }

                if fetchedCount >= offset {
                    // metaForAsset hits asset resources for mime/ext - dont pay this
                    // cost for assets below the offset that we'd just throw away
                    let meta = self.metaForAsset(asset)
                    var assetItem: [String: Any] = [
                        Constants.pId: asset.localIdentifier,
                        Constants.pName: meta.name,
                        Constants.pType: meta.mimeType,
                        Constants.pDate: self.dateFormat.string(from: asset.creationDate ?? Date()),
                        Constants.pTs: Int64((asset.creationDate ?? Date()).timeIntervalSince1970 * 1000),
                        Constants.pDuration: asset.duration,
                        Constants.pWidth: asset.pixelWidth,
                        Constants.pHeight: asset.pixelHeight,
                        Constants.pFavorited: asset.isFavorite
                    ]

                    if let location = asset.location {
                        assetItem[Constants.pLat] = location.coordinate.latitude
                        assetItem[Constants.pLon] = location.coordinate.longitude
                    }

                    let assetIdPathless = asset.localIdentifier.components(separatedBy: "/").first ?? ""
                    let uriString = "assets-library://asset/asset.\(meta.ext)?id=\(assetIdPathless)&ext=\(meta.ext)"
                    assetItem[Constants.pUri] = uriString

                    result.append(assetItem)

                    if limit > 0 && result.count >= limit {
                        stopAssets.pointee = true
                        stopCollections.pointee = true
                        return
                    }
                }
                fetchedCount += 1
            }
            if limit > 0 && result.count >= limit {
                stopCollections.pointee = true
                return
            }
        }

        return result
    }

    @objc(thumbnail:)
    func thumbnail(command: CDVInvokedUrlCommand) {
        checkPermissions(of: command) { [weak self] in
            guard let self = self else { return }
            
            guard let asset = self.assetByCommand(command: command) else {
                // assetByCommand already sends failure
                return
            }
            
            let options: [String: Any] = self.arg(of: command, at: 1, default: [:] as [String: Any])
            let sizeOpt = self.valueFrom(dictionary: options, byKey: Constants.pSize, default: NSNumber(value: Constants.defSize)) // Keep as NSNumber for integerValue
            let qualityOpt = self.valueFrom(dictionary: options, byKey: Constants.pQuality, default: NSNumber(value: Constants.defQuality))
            
            var size = sizeOpt.intValue
            if size <= 0 { size = Constants.defSize }
            var quality = qualityOpt.intValue
            if quality <= 0 { quality = Constants.defQuality }
            let asDataUrl = self.valueFrom(dictionary: options, byKey: Constants.pAsDataUrl, default: false)

            if asset.mediaType == .image || asset.mediaType == .video {
                let reqOptions = PHImageRequestOptions()
                reqOptions.resizeMode = .exact // PHImageRequestOptionsResizeModeExact
                reqOptions.isNetworkAccessAllowed = true
                reqOptions.isSynchronous = true // For direct result handling as in ObjC
                reqOptions.deliveryMode = .highQualityFormat // PHImageRequestOptionsDeliveryModeHighQualityFormat

                PHImageManager.default().requestImage(for: asset,
                                                      targetSize: CGSize(width: size, height: size),
                                                      contentMode: .default, // PHImageContentModeDefault
                                                      options: reqOptions) { [weak self] (resultImage, info) in
                    guard let self = self else { return }
                    
                    if let error = info?[PHImageErrorKey] as? Error {
                        self.failure(command: command, message: error.localizedDescription)
                        return
                    }
                    guard let image = resultImage else {
                        self.failure(command: command, message: Constants.ePhotoNoData)
                        return
                    }

                    // The original code draws the image into a new context.
                    // This might be to ensure the exact size or deal with orientation implicitly.
                    // For safety, replicating this step.
                    UIGraphicsBeginImageContext(image.size)
                    image.draw(in: CGRect(origin: .zero, size: image.size))
                    let processedImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    guard let finalImage = processedImage, let data = finalImage.jpegData(compressionQuality: CGFloat(quality) / 100.0) else {
                        self.failure(command: command, message: Constants.ePhotoThumb)
                        return
                    }
                    
                    if asDataUrl {
                        let dataUrl = String(format: Constants.tDataUrl, data.base64EncodedString())
                        self.success(command: command, message: dataUrl)
                    } else {
                        self.success(command: command, data: data)
                    }
                }
            } else {
                 self.failure(command: command, message: "Asset is not an image or video type for thumbnail generation.")
            }
        }
    }

    @objc(image:)
    func image(command: CDVInvokedUrlCommand) {
        checkPermissions(of: command) { [weak self] in
            guard let self = self else { return }
            
            guard let asset = self.assetByCommand(command: command) else {
                // assetByCommand already sends failure
                return
            }

            // In Swift, requestImageDataAndOrientation is preferred over requestImageData for modern handling
            let reqOptions = PHImageRequestOptions()
            reqOptions.isNetworkAccessAllowed = true
            reqOptions.progressHandler = { (progress, error, stop, info) in
                print("progress: \(String(format: "%.2f", progress)), info: \(info ?? [:])")
                if let error = error {
                    print("error: \(error)")
                    stop.pointee = true
                }
            }
            // reqOptions.isSynchronous = false // Prefer async for better UX, though original might have implied sync by its structure
            // reqOptions.version = .current // Get the most recent version including edits
            // reqOptions.deliveryMode = .highQualityFormat

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: reqOptions) { [weak self] (imageData, dataUTI, orientation, info) in
                guard let self = self else { return }

                if let error = info?[PHImageErrorKey] as? Error {
                    self.failure(command: command, message: error.localizedDescription)
                    return
                }
                guard let data = imageData else {
                    self.failure(command: command, message: Constants.ePhotoNoData)
                    return
                }
                
                guard let cgImage = UIImage(data: data)?.cgImage else {
                    self.failure(command: command, message: "Could not create CGImage from data.")
                    return
                }
                
                // Convert CGImagePropertyOrientation to UIImage.Orientation
                let uiOrientation = self.convertOrientation(orientation)
                let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: uiOrientation)
                
                // Now normalize and convert to sRGB in one step
                guard let finalImage = self.normalizeAndConvertToSRGB(image) else {
                    self.failure(command: command, message: "Could not convert colorspace")
                    return
                }
                
                guard let mediaData = finalImage.jpegData(compressionQuality: 0.8) else {
                    self.failure(command: command, message: "Could not get JPEG representation of image.")
                    return
                }
                self.success(command: command, data: mediaData)
            }
        }
    }
    
    func normalizeAndConvertToSRGB(_ image: UIImage) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.preferredRange = .standard  // sRGB
        
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    
    func convertOrientation(_ cgOrientation: CGImagePropertyOrientation) -> UIImage.Orientation {
        switch cgOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        }
    }

    // UIImage(data: data) generally handles orientation correctly.
    // If specific manual rotation like the original Objective-C code is required,
    // this function would need to be implemented carefully, mapping UIImage.Orientation
    // to the specific transforms. For now, relying on modern UIImage behavior.
    /*
    private func rotateUIImage(sourceImage: UIImage, orientation: CGImagePropertyOrientation) -> UIImage {
        // This function would need careful implementation if UIImage(data:) isn't sufficient.
        // The original logic was specific about which orientations to transform.
        // Modern iOS handles many orientations automatically when loading image data.
        return sourceImage // Placeholder
    }
    */
    
    func convertImageToSRGB(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Draw respecting orientation by using UIImage's draw method
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        
        guard let newCGImage = context.makeImage() else { return nil }
        
        // Orientation is now baked in, so use .up
        return UIImage(cgImage: newCGImage, scale: image.scale, orientation: .up)
    }

    @objc(video:)
    func video(command: CDVInvokedUrlCommand) {
        checkPermissions(of: command) { [weak self] in
            guard let self = self else { return }
            
            guard let asset = self.assetByCommand(command: command) else {
                // assetByCommand already sends failure
                return
            }

            guard asset.mediaType == .video else {
                self.failure(command: command, message: "Asset is not a video")
                return
            }

            // Setting isNetworkAccessAllowed to true allows Photos to download the video from iCloud if it is not on the local device.
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .current // Get original video

            options.progressHandler = { [weak self] progress, error, stop, info in
                guard let self = self else { return }

                if let error = error {
                    print("Error downloading video from iCloud: \(error.localizedDescription)")
                    stop.pointee = true
                    // The export session will also fail, which will send a failure message.
                    return
                }

                // Send progress update to JavaScript
                let progressUpdate: [String: Any] = ["type": "download_progress", "progress": progress]
                let pluginResult = CDVPluginResult(status: .ok, messageAs: progressUpdate)
                pluginResult.setKeepCallbackAs(true)
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }

            PHImageManager.default().requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPresetPassthrough) { [weak self] (exportSession, info) in
                guard let self = self else { return }

                if let error = info?[PHImageErrorKey] as? Error { // Check for specific PHImageErrorKey
                    self.failure(command: command, message: error.localizedDescription)
                    return
                }

                guard let session = exportSession else {
                    self.failure(command: command, message: "Could not create export session for video asset")
                    return
                }

                let outputFilePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(asset.localIdentifier.replacingOccurrences(of: "/", with: "_")).mov")
                
                // Remove existing file if any
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: outputFilePath.path) {
                    do {
                        try fileManager.removeItem(at: outputFilePath)
                    } catch let error {
                        self.failure(command: command, message: "Could not remove existing temp file: \(error.localizedDescription)")
                        return
                    }
                }
                
                session.outputURL = outputFilePath
                
                // Determine a suitable output file type.
                if session.supportedFileTypes.contains(.mov) {
                    session.outputFileType = .mov
                } else if let firstSupportedType = session.supportedFileTypes.first {
                    session.outputFileType = firstSupportedType
                } else {
                    self.failure(command: command, message: "No supported output file types for export session")
                    return
                }

                session.exportAsynchronously { [weak self] in
                    guard let self = self else { return }
                    switch session.status {
                    case .exporting:
                        let result = ["type":"export_progress","uri": session.progress.description]
                        self.success(command: command, json: result)
                    case .completed:
                        let result = ["type":"download_complete","uri": outputFilePath.absoluteString]
                        self.success(command: command, json: result)
                    case .failed:
                        let errorMessage = session.error?.localizedDescription ?? "Video export failed with unknown error"
                        self.failure(command: command, message: "Video export failed: \(errorMessage)")
                    case .cancelled:
                        self.failure(command: command, message: "Video export cancelled")
                    default:
                        self.failure(command: command, message: "Video export completed with unexpected status: \(session.status.rawValue)")
                    }
                }
            }
        }
    }

    @objc(cancel:)
    func cancel(command: CDVInvokedUrlCommand) {
        // The photosCommand is shared by photos and videos fetching operations.
        // Setting it to nil should signal those operations to stop if they are checking it.
        self.photosCommand = nil
        self.success(command: command) // Send OK for cancellation itself
    }
}

extension String {
    func toInt() -> Int? {
        return Int(self)
    }
}

@available(iOS 14, *)
extension CDVPhotos: PHPickerViewControllerDelegate {
    func presentPHPicker(command: CDVInvokedUrlCommand) {
        if self.pickerCommand != nil {
            self.failure(command: command, message: "Picker is already presented")
            return
        }

        let options: [String: Any] = self.arg(of: command, at: 0, default: [:] as [String: Any])

        // cordova's JS->native bridge can hand back a JS number as NSNumber, Double, or
        // even a String depending on platform/version. as? Int alone is unreliable - try
        // each shape before falling back to unlimited.
        var limit = 0
        if let raw = options[Constants.pListLimit] {
            if let intVal = raw as? Int { limit = intVal }
            else if let nsNum = raw as? NSNumber { limit = nsNum.intValue }
            else if let dblVal = raw as? Double { limit = Int(dblVal) }
            else if let strVal = raw as? String, let parsed = Int(strVal) { limit = parsed }
        }
        let mediaType = ((options["mediaType"] as? String) ?? "image").lowercased()
        print("pickPhotos: selectionLimit=\(limit), mediaType=\(mediaType)")

        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = limit   // 0 == unlimited
        switch mediaType {
            case "video": config.filter = .videos
            case "any":   config.filter = nil
            default:      config.filter = .images
        }
        if #available(iOS 15, *) {
            // preserve the order in which the user tapped photos
            config.selection = .ordered
        }

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        self.pickerCommand = command

        DispatchQueue.main.async {
            self.viewController?.present(picker, animated: true)
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let command = self.pickerCommand else { return }
        self.pickerCommand = nil

        if results.isEmpty {
            // user cancelled - an empty array so JS resolves cleanly
            self.success(command: command, array: [])
            return
        }

        let identifiers = results.compactMap { $0.assetIdentifier }
        if identifiers.isEmpty {
            // they DID pick something but the system withheld the asset identifiers (limited
            // library access, or a provider that does not expose them).  this used to come
            // back as an empty array too, which JS treated as a cancel - the user tapped
            // videos, nothing happened, and nobody was told why
            self.failure(command: command, message: "Photo library access is limited - the selected items could not be identified")
            return
        }

        // build dicts keyed by localIdentifier so we can preserve user pick order
        // when assembling the final array (fetchAssets doesnt guarantee input order)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var byId: [String: [String: Any]] = [:]
        fetchResult.enumerateObjects { (asset, _, _) in
            let meta = self.metaForAsset(asset)
            var assetItem: [String: Any] = [
                Constants.pId: asset.localIdentifier,
                Constants.pName: meta.name,
                Constants.pType: meta.mimeType,
                Constants.pDate: self.dateFormat.string(from: asset.creationDate ?? Date()),
                Constants.pTs: Int64((asset.creationDate ?? Date()).timeIntervalSince1970 * 1000),
                Constants.pDuration: asset.duration,
                Constants.pWidth: asset.pixelWidth,
                Constants.pHeight: asset.pixelHeight,
                Constants.pFavorited: asset.isFavorite
            ]
            if let location = asset.location {
                assetItem[Constants.pLat] = location.coordinate.latitude
                assetItem[Constants.pLon] = location.coordinate.longitude
            }
            let assetIdPathless = asset.localIdentifier.components(separatedBy: "/").first ?? ""
            let uriString = "assets-library://asset/asset.\(meta.ext)?id=\(assetIdPathless)&ext=\(meta.ext)"
            assetItem[Constants.pUri] = uriString
            byId[asset.localIdentifier] = assetItem
        }

        var result: [[String: Any]] = []
        for identifier in identifiers {
            if let item = byId[identifier] { result.append(item) }
        }

        self.success(command: command, array: result)
    }
}
