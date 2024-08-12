python -m pip install --upgrade build
# Increase version at setup.py
rm -rf dist/*
python -m build
