from azure.storage.blob import BlobServiceClient, ContentSettings

class BlobStorage:
    def __init__(self, connection_string):
        self.blob_service_client = BlobServiceClient.from_connection_string(connection_string)

    def list(self, container_name, prefix=None):
        container_client = self.blob_service_client.get_container_client(container_name)
        blobs = container_client.list_blobs(name_starts_with=prefix)
        return blobs

    def upload(self, container_name, blob_name, data, content_type=None):
        container_client = self.blob_service_client.get_container_client(container_name)
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(data, content_settings=ContentSettings(content_type=content_type))

    def download(self, container_name, blob_name):
        container_client = self.blob_service_client.get_container_client(container_name)
        blob_client = container_client.get_blob_client(blob_name)
        data = blob_client.download_blob().readall()
        return data

    def copy(self, source_container_name, source_blob_name, destination_container_name, destination_blob_name):
        source_container_client = self.blob_service_client.get_container_client(source_container_name)
        source_blob_client = source_container_client.get_blob_client(source_blob_name)
        destination_container_client = self.blob_service_client.get_container_client(destination_container_name)
        destination_blob_client = destination_container_client.get_blob_client(destination_blob_name)
        destination_blob_client.start_copy_from_url(source_blob_client.url)

    def delete(self, container_name, blob_name):
        container_client = self.blob_service_client.get_container_client(container_name)
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.delete_blob()
