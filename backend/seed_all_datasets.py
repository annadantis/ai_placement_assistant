import sys
from data_importer import import_branch_data

datasets = [
    ('datasets/civ_mcq.csv', 'CIVIL', 'technical'),
    ('datasets/eee_mcq.csv', 'EEE', 'technical'),
    ('datasets/enhanced_cse_dataset.csv', 'CSE', 'technical'),
    ('datasets/mechengineering_mcqs.csv', 'MECH', 'technical'),
    ('datasets/measurements_instrumentation_questions - measurements_instrumentation_questions.csv', 'AEI', 'technical'),
    ('datasets/enhanced_clean_general_aptitude_dataset.csv', 'COMMON', 'aptitude')
]

for path, branch, category in datasets:
    import_branch_data(path, branch, category, False)
    print(f"Seeded {branch} {category}")

print("Seeding Complete!")
