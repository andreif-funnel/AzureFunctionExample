import logging
import os

import azure.functions
import azure.storage.blob
import boto3


def main(blin: azure.functions.InputStream):
    logging.info(f"Python blob trigger function processed blob \n"
                 f"Name: {blin.name}\n"
                 f"Blob Size: {blin.length} bytes")

    data = blin.read()
    logging.info(data)

    s3 = boto3.client(
        "s3",
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
    )
    filename = os.path.basename(blin.name)
    token, filename = filename.split('_')
    bucket = os.environ["AWS_S3_BUCKET"]
    s3_key = f"{token}/{filename}"
    s3.put_object(Bucket=bucket, Key=s3_key, Body=blin.read())
    s3.get_waiter("object_exists").wait(
        Bucket=bucket, Key=s3_key, WaiterConfig={"Delay": 2, "MaxAttempts": 5},
    )
    bs = azure.storage.blob.BlockBlobService(connection_string=os.environ["AzureWebJobsStorage"])
    container = "my-container"
    bs.delete_blob(container_name=container, blob_name=filename)
    logging.info([b.name for b in bs.list_blobs(container_name=container)])
