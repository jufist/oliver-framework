python -m pip install --upgrade build

- Increase version at setup.py as package.json

```
rm -rf dist/*
rm -rf build/lib/oliver_framework/*;
cp -rf python/* build/lib/oliver_framework/
python -m build
git add *
git commit -m LatestBuild# 
git push
rm -rf sass/lib/python3.8/site-packages/oliver_framework*
pip install --upgrade git+https://github.com/jufist/oliver-framework.git
```
