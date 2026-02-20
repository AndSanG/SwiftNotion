<!-- notion-id: 30de582f-073d-8176-96f0-fa33a2b124ec -->
# My New Project
<!-- notion-id: 30de582f-073d-8139-82df-f0b33e468ca7 -->
- [x] Task 1 (Story 2) Create test page in Local and Push to Notion
<!-- notion-id: 30de582f-073d-81e6-a5c1-c4592a632478 -->
```swift
swift run SwiftNotion push notes.md 2e0e582f073d804db5e4d75c2d271c25



```
<!-- notion-id: 30de582f-073d-816c-8da8-fcfc7b512da5 -->
- [x] Task 2 (Story 1) Pull Notion to Local
<!-- notion-id: 30de582f-073d-8159-88b3-c81afdf28848 -->
```swift
// pull from notion id 30de582f-073d-81da-8181-fa3330099019 to local file pulled_notes.md
swift run SwiftNotion pull 30de582f073d81da8181fa3330099019 pulled_notes.md
// pull from notion id 2eee582f073d80588e56f1fd9f9f7812 to local file pulled_notes_Effectivelly.md
swift run SwiftNotion pull 2eee582f073d80588e56f1fd9f9f7812 pulled_notes_Effectivelly.md


```
<!-- notion-id: 30de582f-073d-8140-a956-f97fad3acab2 -->
- [x] Task 3 (Story 3) Sync/Update Notion page from Local
<!-- notion-id: 30de582f-073d-81d9-99c7-fd61668cae07 -->
```swift
// update notion page 30de582f-073d-81da-8181-fa3330099019 with local file notes.md
swift run SwiftNotion sync 30de582f073d81da8181fa3330099019 notes.md


```
<!-- notion-id: 30de582f-073d-8113-be19-e65b1804806a -->
- [x] Task 4 (Story 4) Delete Notion page from Local
<!-- notion-id: 30de582f-073d-8007-96a5-c994638add56 -->
```swift
swift run SwiftNotion delete 30de582f073d81da8181fa3330099019
```
