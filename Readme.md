# SwiftNotion

## CLI Interface

The `SwiftNotion` executable provides several commands to interact with your Notion pages.

### Environment Setup

Create a `.env` file in the root directory and add your Notion API Integration Token:

```bash
NOTION_KEY="your_notion_integration_token"
```

You can use `.env.example` as a template.

### Commands

#### 1. Pull Notion Page (Read)
Fetch a Notion page and save it as a local Markdown file.

**Usage:**
```bash
swift run SwiftNotion pull <page-id> <file-path>
```
- `<page-id>`: The ID of the Notion page you want to pull.
- `<file-path>`: The local path where the Markdown file will be saved.

#### 2. Push to Notion (Create)
Create a new Notion page from a local Markdown file. The command will extract the title from the first H1 in the file and write back the generated Notion IDs to the file.

**Usage:**
```bash
swift run SwiftNotion push <file-path> <parent-id>
```
- `<file-path>`: Path to your local `.md` file.
- `<parent-id>`: The ID of the parent page or database where the new page will be created.

#### 3. Sync Updates (Update)
Update an existing Notion page with changes from a local Markdown file. It uses embedded IDs to update, append, or delete blocks.

**Usage:**
```bash
swift run SwiftNotion sync <file-path> <page-id>
```
- `<file-path>`: Path to your local `.md` file.
- `<page-id>`: The ID of the Notion page to sync with.

#### 4. Delete Notion Page (Delete)
Archive a Notion page.

**Usage:**
```bash
swift run SwiftNotion delete <page-id>
```
- `<page-id>`: The ID of the Notion page to archive.

#### 5. Test Parser
Test the local Markdown parser by reading a file and outputting the parsed block types and IDs.

**Usage:**
```bash
swift run SwiftNotion test <file-path>
```
- `<file-path>`: Path to the local Markdown file to test.

### Examples

**Download a Notion page:**
```bash
swift run SwiftNotion pull 1a2b3c4d5e6f7g8h9i0j notebook.md
```

**Create a new page from Markdown:**
```bash
swift run SwiftNotion push new_feature.md 1a2b3c4d5e6f7g8h9i0j
```

**Sync updates to Notion:**
```bash
swift run SwiftNotion sync notebook.md 1a2b3c4d5e6f7g8h9i0j
```

## BDD Specs

### Story: Pull Notion page into Git repository (Read)

### Narrative #1

```
As an git and Notion user 
I want the App to pull the new page to my git repository.
So I can always have the latest version of my page in my git repository.
```

#### Scenarios (Acceptance criteria)

```
Given a Notion page configured to be exposed through Notion API
    And a Git repo configured to be synced with the Notion page
    When user creates new page "Meeting Notes" in Notion page
    Then the app should pull the new page to the git repository.
    And the new page should be saved as a markdown file in the git repository.
```

### Story: Create Notion page from Git repository (Create)

### Narrative #2

```
As a git and Notion user
I want the App to push a new markdown file to my Notion workspace.
So I can create new Notion pages directly from my git repository.
```

#### Scenarios (Acceptance criteria)

```
Given a Markdown file in a Git repo configured to be synced
    And a Notion workspace configured to be exposed through Notion API
    When user executes the push command for the new file
    Then the app should create a new page in Notion.
    And the Notion page should reflect the markdown file's content.
```

### Story: Update Notion page from Git repository (Update)

### Narrative #3

```
As a git and Notion user
I want the App to push changes in my markdown file to my Notion workspace.
So I can keep my Notion pages up to date using my git repository.
```

#### Scenarios (Acceptance criteria)

```
Given a Markdown file linked to an existing Notion page
    And a Git repo configured to be synced
    When user modifies the markdown file and executes the sync command
    Then the app should update the corresponding blocks in the Notion page.
    And the Notion page should reflect the updated markdown file's content.
```

### Story: Delete Notion page from Git repository (Delete)

### Narrative #4

```
As a git and Notion user
I want the App to archive/delete a Notion page when I delete its corresponding markdown file.
So I can manage my Notion pages' lifecycle from my git repository.
```

#### Scenarios (Acceptance criteria)

```
Given a Markdown file linked to an existing Notion page
    And a Git repo configured to be synced
    When user deletes the markdown file and executes the sync command
    Then the app should archive or delete the corresponding page in Notion.
```

## Use Cases

### Pull Notion page changes into Git repository (Read)

#### Data:
- Notion page with integration token
- Git repository

#### Primary course (happy path):
1. Execute "Pull Notion page changes" command with above data.
2. System requests the Notion page content using the integration token.
3. System receives the Notion page blocks successfully.
4. System parses the page blocks and converts them into Markdown format.
5. System creates or updates the corresponding Markdown file in the Git repository.

#### Invalid data – error course (sad path):
1. System delivers invalid data error to the user.

#### No connectivity – error course (sad path): 
1. System delivers connectivity error to the user.

### Create Notion page from Git repository (Create)

#### Data:
- Markdown file in the Git repository
- Notion integration token and target parent page/database ID

#### Primary course (happy path):
1. Execute "Push to Notion" command with the new Markdown file.
2. System parses the Markdown file into Notion block models.
3. System sends a request to the Notion API to create a new page with the parsed blocks.
4. System receives the success response with the new page ID.
5. System updates the local Markdown file with Notion block IDs for future syncing.

#### Invalid data – error course (sad path):
1. System receives an unauthorized or invalid parent ID error.
2. System delivers invalid data error to the user.

#### No connectivity – error course (sad path): 
1. System delivers connectivity error to the user.

### Update Notion page from Git repository (Update)

#### Data:
- Modified Markdown file (with existing Notion block IDs)
- Notion integration token

#### Primary course (happy path):
1. Execute "Sync to Notion" command with the modified Markdown file.
2. System parses the Markdown file and identifies new, modified, or deleted blocks.
3. System sends requests to the Notion API to update, append, or delete block children on the respective page.
4. System receives the success responses for the operations.
5. System updates the local Markdown file with any newly generated Notion block IDs.

#### Invalid data – error course (sad path):
1. System receives errors indicating blocks were deleted manually in Notion or token is invalid.
2. System delivers synchronization conflict or invalid data error to the user.

#### No connectivity – error course (sad path): 
1. System delivers connectivity error to the user.

### Delete Notion page from Git repository (Delete)

#### Data:
- ID or path of the deleted Markdown file
- Notion integration token and corresponding page ID

#### Primary course (happy path):
1. Execute "Delete Notion page" command (or sync detects file deletion).
2. System sends a request to the Notion API to archive the page associated with the deleted file.
3. System receives success response confirming the page is archived.
4. System resolves the sync state.

#### Invalid data – error course (sad path):
1. System receives an unauthorized or "page not found" error if it was already deleted.
2. System delivers a warning or invalid data error to the user.

#### No connectivity – error course (sad path): 
1. System delivers connectivity error to the user.
