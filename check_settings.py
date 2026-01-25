
protocol_lines = open('MacFileExplorer/Sources/Core/Storage/SettingsStoreProtocol.swift').readlines()
impl_lines = open('MacFileExplorer/Sources/Core/Storage/SettingsStore.swift').readlines()

protocol_vars = []
for line in protocol_lines:
    if 'var ' in line and '{ get set }' in line:
        var_name = line.split('var ')[1].split(':')[0].strip()
        protocol_vars.append(var_name)

impl_vars = []
for line in impl_lines:
    if 'var ' in line and '{' in line:
        var_name = line.split('var ')[1].split(':')[0].strip()
        impl_vars.append(var_name)

missing = [v for v in protocol_vars if v not in impl_vars]
print(f"Missing vars: {missing}")

protocol_funcs = []
for line in protocol_lines:
    if 'func ' in line and '{' not in line:
        func_name = line.split('func ')[1].split('(')[0].strip()
        protocol_funcs.append(func_name)

impl_funcs = []
for line in impl_lines:
    if 'func ' in line and '{' in line:
        func_name = line.split('func ')[1].split('(')[0].strip()
        impl_funcs.append(func_name)

missing_funcs = [f for f in protocol_funcs if f not in impl_funcs]
print(f"Missing funcs: {missing_funcs}")
