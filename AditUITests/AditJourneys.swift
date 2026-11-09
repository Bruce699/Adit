import XCTest

final class AditJourneys: XCTestCase {
  let app = XCUIApplication()
  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchArguments = ["--ui-test", "--reset-test-library"]
    app.launch()
  }
  func capture(_ name: String) {
    let a = XCTAttachment(screenshot: app.screenshot())
    a.name = name
    a.lifetime = .keepAlways
    add(a)
  }
  func openEditor() {
    let friend = app.buttons["Friend.com, 596 reframes"]
    XCTAssertTrue(friend.waitForExistence(timeout: 10))
    friend.tap()
    let start = app.buttons["Reframe"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    capture("Campaign picker")
    start.tap()
    XCTAssertTrue(app.buttons["AI brush"].waitForExistence(timeout: 6))
  }
  func testRideFromWallToPublication() {
    XCTAssertTrue(app.buttons["Choose station"].waitForExistence(timeout: 10))
    sleep(2)
    capture("01 Station wall")
    openEditor()
    capture("02 Editor")
    let canvas = app.descendants(matching: .any).matching(identifier: "canvas").firstMatch
    XCTAssertTrue(canvas.exists)
    canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.66)).tap()
    let prompt = app.textFields["Describe an asset…"]
    XCTAssertTrue(prompt.waitForExistence(timeout: 4))
    XCTAssertFalse(app.buttons["Queue prompt"].isEnabled)
    prompt.tap()
    prompt.typeText("Joe Goldberg")
    app.buttons["Queue prompt"].tap()
    XCTAssertFalse(app.buttons["Finish"].isEnabled)
    capture("Pending region")
    app.buttons["Brush"].tap()
    let a = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.42))
    a.press(
      forDuration: 0.2,
      thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.43)))
    app.buttons["Undo"].tap()
    XCTAssertTrue(app.buttons["Redo"].isEnabled)
    app.buttons["Redo"].tap()
    app.buttons["Add text"].tap()
    let field = app.textFields["typeInput"]
    XCTAssertTrue(field.waitForExistence(timeout: 4))
    field.tap()
    field.typeText("YOU")
    app.buttons["Place"].tap()
    app.buttons["Save draft and close"].tap()
    app.buttons["Artist profile"].tap()
    app.buttons["Drafts"].tap()
    app.buttons["Resume draft"].firstMatch.tap()
    let finish = app.buttons["Finish"]
    XCTAssertTrue(finish.wait(for: \.isEnabled, toEqual: true, timeout: 22))
    capture("03 Completed edit")
    finish.tap()
    let back = app.buttons["Reframe"]
    XCTAssertTrue(back.waitForExistence(timeout: 5))
    capture("04 Published reframe")
    back.tap()
    XCTAssertTrue(app.buttons["Friend.com, 597 reframes"].waitForExistence(timeout: 5))
    app.terminate()
    app.launchArguments = ["--ui-test"]
    app.launch()
    XCTAssertTrue(app.buttons["Friend.com, 597 reframes"].waitForExistence(timeout: 8))
  }
  func testCommunityAndProfile() {
    let tab = app.buttons["Explore"]
    XCTAssertTrue(tab.waitForExistence(timeout: 10))
    tab.tap()
    capture("05 Explore")
    let vote = app.buttons["Vote hall of fame"].firstMatch
    for _ in 0..<4 where !vote.isHittable { app.swipeUp() }
    XCTAssertTrue(vote.isHittable)
    vote.tap()
    XCTAssertEqual(vote.value as? String, "Selected")
    vote.tap()
    XCTAssertEqual(vote.value as? String, "Unselected")
    let bookmark = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH 'Save ' AND label ENDSWITH ' poster'")
    ).firstMatch
    bookmark.tap()
    app.buttons["Artist profile"].tap()
    capture("06 Artist profile")
    app.buttons["Saved"].tap()
    XCTAssertTrue(app.buttons["Open Saved reframe"].firstMatch.exists)
    app.buttons["Edit artist name"].tap()
    let name = app.alerts.textFields.firstMatch
    name.tap()
    name.typeText("NYC")
    app.buttons["Save"].tap()
    app.buttons["Station wall"].tap()
    app.buttons["Choose station"].tap()
    app.buttons["33 Street Station"].tap()
    XCTAssertFalse(app.staticTexts["Stations"].exists)
  }
  func testBrandAssetsAndDraftRecovery() {
    openEditor()
    app.buttons["Asset library"].tap()
    capture("07 Asset library")
    app.buttons["Place necklace"].tap()
    app.buttons["Enlarge layer"].tap()
    app.buttons["Rotate layer"].tap()
    app.buttons["Save draft and close"].tap()
    app.terminate()
    app.launchArguments = ["--ui-test"]
    app.launch()
    app.buttons["Artist profile"].tap()
    app.buttons["Drafts"].tap()
    app.buttons["Resume draft"].firstMatch.tap()
    XCTAssertTrue(app.buttons["Finish"].exists)
    app.buttons["Save draft and close"].tap()
    app.buttons["Delete draft"].firstMatch.tap()
    app.buttons.matching(identifier: "Delete draft").allElementsBoundByIndex.last!.tap()
    XCTAssertTrue(app.staticTexts["No drafts yet"].waitForExistence(timeout: 4))
  }
}
