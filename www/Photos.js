var exec = require("cordova/exec");

var Photos = {
	collections: function (options, successCallback, errorCallback) {
		if (typeof options === "function") {
			errorCallback = successCallback;
			successCallback = options;
			options = null;
		}
		exec(successCallback, errorCallback, "Photos", "collections", [
			options
		]);
	},

	photos: function (collectionIds, options, successCallback, errorCallback) {
		switch (typeof collectionIds) {
			case "function":
				errorCallback = options;
				successCallback = collectionIds;
				options = null;
				collectionIds = null;
				break;
			case "string":
				collectionIds = [collectionIds];
				if (typeof options == "function") {
					errorCallback = successCallback;
					successCallback = options;
					options = null;
				}
				break;
			case "object":
				if (collectionIds.constructor !== Array) {
					errorCallback = successCallback;
					successCallback = options;
					options = collectionIds;
					collectionIds = null;
				}
				break;
		}
		exec(successCallback, errorCallback, "Photos", "photos", [
			collectionIds,
			options
		]);
	},

	videos: function (collectionIds, options, successCallback, errorCallback) {
		switch (typeof collectionIds) {
			case "function":
				errorCallback = options;
				successCallback = collectionIds;
				options = null;
				collectionIds = null;
				break;
			case "string":
				collectionIds = [collectionIds];
				if (typeof options == "function") {
					errorCallback = successCallback;
					successCallback = options;
					options = null;
				}
				break;
			case "object":
				if (collectionIds.constructor !== Array) {
					errorCallback = successCallback;
					successCallback = options;
					options = collectionIds;
					collectionIds = null;
				}
				break;
		}
		exec(successCallback, errorCallback, "Photos", "videos", [
			collectionIds,
			options
		]);
	},

	thumbnail: function (photoId, options, successCallback, errorCallback) {
		if (typeof options === "function") {
			errorCallback = successCallback;
			successCallback = options;
			options = null;
		}
		exec(successCallback, errorCallback, "Photos", "thumbnail", [
			photoId,
			options
		]);
	},

	image: function (photoId, successCallback, errorCallback) {
		exec(successCallback, errorCallback, "Photos", "image", [photoId]);
	},

	// iOS only: the full-size JPEG written to <tmp>/<fileName>. same image as image(), without
	// the bytes crossing the bridge. the success callback gets {type:"download_progress",
	// progress:0-1} while iCloud hands the photo over, then {type:"download_complete", uri}
	imageToFile: function (photoId, fileName, successCallback, errorCallback) {
		exec(successCallback, errorCallback, "Photos", "imageToFile", [photoId, fileName]);
	},

	video: function (videoId, successCallback, errorCallback) {
		exec(successCallback, errorCallback, "Photos", "video", [videoId]);
	},

	pickPhotos: function (options, successCallback, errorCallback) {
		if (typeof options === "function") {
			errorCallback = successCallback;
			successCallback = options;
			options = null;
		}
		exec(successCallback, errorCallback, "Photos", "pickPhotos", [
			options || {}
		]);
	},

	cancel: function () {
		exec(null, null, "Photos", "cancel", []);
	},

	getPhotoLibraryAuthorization: function (successCallback, errorCallback) {
		exec(
			successCallback,
			errorCallback,
			"Photos",
			"getPhotoLibraryAuthorization",
			[]
		);
	},

	requestPhotoLibraryAuthorization: function (
		successCallback,
		errorCallback
	) {
		exec(
			successCallback,
			errorCallback,
			"Photos",
			"requestPhotoLibraryAuthorization",
			[]
		);
	}
};

module.exports = Photos;
