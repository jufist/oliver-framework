from setuptools import setup


# Use an explicit package list so the code in python/ is installed as
# oliver_framework instead of the unintended top‑level "python" package.
packages = [
    "oliver_framework",
    "oliver_framework.utils",
]


setup(
    name="oliver_framework",
    version="1.1.6",
    description="Oliver Python Framework",
    author="Oliver Huynh",
    author_email="oliver@jufist.com",
    url="https://github.com/oliverhuynh/oliver-framework",
    packages=packages,
    package_dir={
        "oliver_framework": "python",
        "oliver_framework.utils": "python/utils",
    },
    install_requires=[
        "azure-storage-blob",
        "pyodbc",
        "python-dotenv",
        "schedule",
        "pydispatcher",
        "sqlalchemy",
        "colorlog",
        "pystray",
        "Pillow",  # PIL fork for handling images
        "tk",  # tk is usually included with Python, but this might not install it as expected
        "sqlparse",
    ],
    include_package_data=True,
    python_requires=">=3.8",
)
