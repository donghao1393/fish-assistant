from setuptools import setup

setup(
    name="fish_assistant",
    version="0.1.0",
    packages=["plugins"],
    package_data={
        "plugins": ["*/functions/*.fish", "*/completions/*.fish", "*/conf.d/*.fish"],
    },
)
