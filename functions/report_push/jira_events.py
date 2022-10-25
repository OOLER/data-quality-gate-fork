from jira import JIRA
import os

API_URL = os.getenv("JIRA_URL")
API_USERNAME = os.getenv("SECRET_NAME_JIRA_USERNAME")
API_PASSWORD = os.getenv("SECRET_NAME_JIRA_PASSWORD")

options = {'server': API_URL}
jira = JIRA(options, basic_auth=(API_USERNAME, API_PASSWORD))


def open_bug(project_key: str, table_name: str, fail_step: str, description: str, replaced_allure_links):
    summary = '[DataQA][BUG][{0}]{1}'.format(table_name, fail_step)
    ticketExist = False
    issues = jira.search_issues('project=' + project_key, maxResults=None)
    for singleIssue in issues:
        if summary == str(singleIssue.fields.summary) and str(
                singleIssue.fields.status) == 'Open':
            ticketExist = True
            break
        elif summary == str(singleIssue.fields.summary) and str(
                singleIssue.fields.status) != 'Open':
            ticketExist = True
            print("Will be reopen bug with name [{0}]".format(summary))
            # jira.transition_issue(singleIssue.key, transition='19')
            break
    if not ticketExist:
        create_new_bug(description, project_key, replaced_allure_links, summary)


def create_new_bug(description, project_key, replaced_allure_links, summary):
    print("Will be created bug with name [{0}]".format(summary))
    # jira.create_issue(
    #     fields={
    #         "project": {"key": project_key},
    #         "issuetype": {"name": "Bug"},
    #         "summary": summary,
    #         "description": description + replaced_allure_links,
    #     }
    # )
