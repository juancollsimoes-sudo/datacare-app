with open('rust/src/db/repository.rs', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'Ok(PaginatedSesiones {' in line and i < 100:  # line 74 is Pacientes
        lines[i] = line.replace('PaginatedSesiones', 'PaginatedPacientes')

with open('rust/src/db/repository.rs', 'w') as f:
    f.writelines(lines)
