with open('rust/src/db/repository.rs', 'r') as f:
    content = f.read()

# Replace PaginatedPacientes with PaginatedSesiones in SesionRepo
content = content.replace(
'''Ok(PaginatedPacientes {
            items,
            total,
            page,
            page_size,
        })''',
'''Ok(PaginatedSesiones {
            items,
            total,
            page,
            page_size,
        })''')

with open('rust/src/db/repository.rs', 'w') as f:
    f.write(content)
