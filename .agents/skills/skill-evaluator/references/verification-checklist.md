# Verification Checklist (absorbed from verification-template)

Starting point for domain-specific verification of new features, modules,
or operations. Copy the categories, replace brackets, run on a real
instance, iterate on what the checklist missed.

## Checklist

### [Operation Name]

- [ ] Requirement 1: [Description of success criteria]
- [ ] Requirement 2: [Description of success criteria]
- [ ] Edge Case 1: [Description of how to verify]

### [Data Integrity]

- [ ] Roundtrip: [Verify data matches after save/load]
- [ ] Schema: [Verify output adheres to expected schema]

### [Security/Safety]

- [ ] Permission: [Verify restricted access works as intended]
- [ ] Sanitization: [Verify inputs are correctly handled]

## Process

1. **Identify Operation**: what specific action needs verification?
2. **Define Success**: what does a "perfect" execution look like?
3. **Draft Checklist**: use the categories above for specific checks.
4. **Test Checklist**: run the checks on a real instance.
5. **Iterate**: refine based on discovered edge cases.
