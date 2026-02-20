# SwiftNotion

## BDD Specs

### Story: Get Notion page into Git repository

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

## Use Cases

### Pull Notion page changes into Git repository

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
