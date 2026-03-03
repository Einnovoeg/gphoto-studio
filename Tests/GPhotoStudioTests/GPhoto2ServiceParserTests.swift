import XCTest
@testable import GPhotoStudio

/// Parser contract tests for CLI output transformations.
final class GPhoto2ServiceParserTests: XCTestCase {
    func testParseAutoDetectOutputParsesMultipleDevices() {
        // Realistic table layout from `gphoto2 --auto-detect`.
        let output = """
        Model                          Port
        ----------------------------------------------------------
        Canon EOS R6                   usb:001,042
        Nikon DSC D750                 usb:002,005
        """

        let devices = GPhoto2Service.parseAutoDetectOutput(output)

        XCTAssertEqual(
            devices,
            [
                CameraDevice(model: "Canon EOS R6", port: "usb:001,042"),
                CameraDevice(model: "Nikon DSC D750", port: "usb:002,005")
            ]
        )
    }

    func testParseAutoDetectOutputReturnsEmptyWithoutSeparator() {
        let output = """
        Model                          Port
        Canon EOS R6                   usb:001,042
        """

        XCTAssertEqual(GPhoto2Service.parseAutoDetectOutput(output), [])
    }

    func testParseDownloadedPathsParsesAndDeduplicatesSavedFiles() {
        // Tether mode can emit mixed logs with repeated "Saving file as ..." lines.
        let output = """
        New file is in location /store_00010001/DCIM/100CANON/IMG_0001.JPG on the camera
        Saving file as '/tmp/capture-001.jpg'
        Some other message
        Saving file as /tmp/capture-002.jpg
        Saving file as '/tmp/capture-001.jpg'
        """

        let paths = GPhoto2Service.parseDownloadedPaths(from: output)

        XCTAssertEqual(
            paths,
            [
                URL(fileURLWithPath: "/tmp/capture-001.jpg"),
                URL(fileURLWithPath: "/tmp/capture-002.jpg")
            ]
        )
    }

    func testParseDownloadedPathsIgnoresUnrelatedLines() {
        let output = """
        Waiting for events from camera. Press Ctrl-C to abort.
        Timeout reached.
        """

        XCTAssertEqual(GPhoto2Service.parseDownloadedPaths(from: output), [])
    }
}
