"""Check translated Android resources without changing native control logic."""
import re
import xml.etree.ElementTree as ET
from pathlib import Path
root = Path(__file__).resolve().parents[1] / 'android/app/src/main/res'
def strings(directory):
    return {e.attrib['name']: e.text or '' for e in ET.parse(root / directory / 'strings.xml').getroot()}
reference = strings('values')
for directory in ('values-es', 'values-zh'):
    translated = strings(directory)
    assert translated.keys() == reference.keys(), directory
    for key, value in translated.items():
        assert value.strip(), (directory, key)
        assert re.findall(r'%\d+\$[sd]', value) == re.findall(r'%\d+\$[sd]', reference[key]), key
print('Native locale resources: parity, non-empty values and placeholders passed')
