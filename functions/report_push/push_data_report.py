import os
import sys
import s3fs
import boto3
import boto
import boto.s3
import re
import fnmatch
from datetime import date
import json
import awswrangler as wr
import random

from jira_events import open_bug

cloudWatch = boto3.client('cloudwatch')
s3 = boto3.resource('s3')
dynamodb = boto3.resource('dynamodb')
dynamo_table_name = os.environ['QA_DYNAMODB_TABLE']
table = dynamodb.Table(dynamo_table_name)
qa_bucket = os.environ['QA_BUCKET']
environment = os.environ['ENVIRONMENT']
project_key = os.environ['JIRA_PROJECT_KEY']

def handler(event, context):

    replaced_allure_links = event['links'].get('Payload')
    report = event['report'].get('Payload')
    profiling_link = (report.get('profiling'))
    ge_links = report.get('test_suite')
    suite = report.get('suite_name')
    today = str(date.today())
    path = report.get('path')
    file = report.get('suite_name')
    key = report.get('folder_key')
    run_name = report.get('run_name')
    bucket = s3.Bucket(qa_bucket)
    items = []
    failed_test = 0
    df = wr.s3.read_json(path=[f's3://{qa_bucket}/allure/{suite}/{key}/allure-report/history/history-trend.json'])
    result_folder_path = f'allure/{suite}/{key}/result/'
    all_result_files = bucket.objects.filter(Prefix=result_folder_path)
    for result_file_name in all_result_files:
        if result_file_name.key.endswith('result.json'):
            with open(f'{result_folder_path}/{result_file_name.key}') as json_file:
                dataInFile = json.load(json_file)
                status = dataInFile['status']
                if status == "failed":
                    failed_test += 1
                    tableName = dataInFile['labels'][1]['value']
                    failStep = dataInFile['steps'][0]['name']
                    description = dataInFile['description']
                    open_bug(project_key, tableName[:tableName.find('.')], failStep[:failStep.find('.')], description,
                             f'https://{replaced_allure_links}')
    history = json.loads(df.to_json())
    total = history['data']['0']['total']
    failed = history['data']['0']['failed']
    passed = history['data']['0']['passed']
    if failed != 0:
        status = 'failed'
    else:
        status = 'passed'
    local_item = {
            'file':str(random.random()),
            'file_name': file,
            'all': total,
            'allure_link': replaced_allure_links,
            'date': today,
            'failed': failed,
            'ge_link': ge_links,
            'passed': passed,
            'profiling_link': profiling_link,
            'status': status,
            'suite': suite,
            'path': str(path),
            'run_name': run_name
        }
    items.append(local_item)

    with table.batch_writer() as batch:
        for item in items:
            print(item)
            batch.put_item(
                Item=item
            )

    cloudWatch.put_metric_data(
        Namespace='Data-QA',
        MetricData=[
            {
                'MetricName': 'bug_created_count',
                'Dimensions': [
                    {
                        'Name': 'table_name',
                        'Value': suite
                    },
                    {
                        'Name': 'Environment',
                        'Value': environment
                    }
                ],
                'Value': failed_test,
                'Unit': 'Count'
            },
        ]
    )
    return "Dashboard is ready!"
