from setuptools import setup, find_packages

setup(
    name='oliver_framework',
    version='1.1.4',
    packages=find_packages(),# ['oliver_framework.utils'],
    description='Oliver Python Framework',
    author='Oliver Huynh',
    author_email='oliver@jufist.com',
    url='https://github.com/oliverhuynh/oliver-framework',
    package_dir={'oliver_framework': 'python'},  
    install_requires=[
        'azure-storage-blob',
        'pyodbc',
        'python-dotenv',
        'schedule',
        'pydispatcher',
        'sqlalchemy',
        'colorlog',
        'pystray',
        'Pillow',  # This is the PIL fork for handling images
        'tk',  # tk is usually included with Python, but this might not install it as expected
        'sqlparse',
    ],
)
