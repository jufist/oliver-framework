import os
import json
import sys

# Add the parent directory of the 'utils' directory to the module search path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from includes.common import load_env

import shutil
from datetime import datetime, timezone
from os.path import normpath
from utils.logging import getlogger
from includes.mount import map_network_drive
logger=getlogger("files")


direct_container = load_env("DIRECT_CONTAINER")

# Convert a dictionary to a normal object
class DictToObject:
    def __init__(self, dictionary):
        for key, value in dictionary.items():
            setattr(self, key, value)

class FileStorage:
    def __init__(self):
        map_network_drive()
        pass

    def container(self, container_name):
        # Add direct container if need
        if direct_container:
            container_name = direct_container + container_name
        return normpath(container_name)

    def list(self, container_name, prefix=None):
        files_info = []

        container_name = self.container(container_name)

        for root, _, filenames in os.walk(container_name):
            for filename in filenames:
                if prefix is None or filename.startswith(prefix):
                    file_path = os.path.join(root, filename)
                    file_path_normal = normpath(file_path)

                    # Remove the prefix container_name crossed OS, following approach is not good enough
                    rel_path = os.path.relpath(file_path_normal, container_name)
                    created_time = self.get_creation_time(file_path)
                    created_time = datetime.fromisoformat(created_time)
                    file_info = {
                        'name': rel_path,
                        'creation_time': created_time
                    }
                    file_info_object = DictToObject(file_info)
                    files_info.append(file_info_object)
        return files_info

    def get_creation_time(self, file_path):
        return datetime.fromtimestamp(os.path.getctime(file_path), tz=timezone.utc).isoformat()

    def upload(self, container_name, blob_name, data, content_type=None):
        container_name = self.container(container_name)

        destination_path = os.path.join(container_name, blob_name)
        with open(destination_path, 'wb') as file:
            file.write(data)
        # If content_type is provided, you can set it as metadata for the file here

    def download(self, container_name, blob_name):

        container_name = self.container(container_name)

        source_path = os.path.join(container_name, blob_name)

        # Fix the file path error in Windows OS
        source_path = os.path.normpath(source_path)
        with open(source_path, 'rb') as file:
            data = file.read()
        return data

    def copy(self, source_container_name, source_blob_name, destination_container_name, destination_blob_name):

        source_container_name = self.container(source_container_name)
        destination_container_name = self.container(destination_container_name)

        source_path = os.path.join(source_container_name, source_blob_name)
        destination_path = os.path.join(destination_container_name, destination_blob_name)

        # Create the directory for destination_path if it does not exist
        os.makedirs(os.path.dirname(destination_path), exist_ok=True)

        shutil.copy(source_path, destination_path)

    def delete(self, container_name, blob_name):

        container_name = self.container(container_name)

        file_path = os.path.join(container_name, blob_name)
        os.remove(file_path)
