import logging

import azure.functions as func


def main(blin: func.InputStream):
    logging.info(f"Python blob trigger function processed blob \n"
                 f"Name: {blin.name}\n"
                 f"Blob Size: {blin.length} bytes")

    data = blin.read()
    logging.info(data)
