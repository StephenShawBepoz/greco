# Bulk Add Operators - User Guide

## Overview
Add multiple BEPOZ operators to a specific parent group from a CSV file.

## Features
- ✅ Load operators from CSV file
- ✅ Auto-generate 4-digit OpNumbers if not provided
- ✅ Validate unique OpNumbers
- ✅ Create new operators OR update existing ones
- ✅ Assign all operators to selected parent group
- ✅ Option to use parent settings (inherit permissions)
- ✅ Real-time status feedback

## CSV Format

### Required Columns
- `FirstName` - Operator first name (required)
- `LastName` - Operator last name (required)

### Optional Columns
- `OpNumber` - 4-digit operator number (auto-generated if empty)
- `Password` - Operator password (defaults to "1234" if empty)

### Example CSV

```csv
FirstName,LastName,OpNumber,Password
John,Smith,1001,pass123
Sarah,Johnson,,
Mike,Williams,1003,
Emma,Brown,1004,secure456
David,Jones,,
```

**Notes:**
- If `OpNumber` is empty or invalid, a random 4-digit number will be generated
- If `Password` is empty, default password "1234" will be used
- Auto-generated OpNumbers are validated for uniqueness

## Parent Groups

### IsParent Values
- **0** - Regular operator (user account)
- **1** - Parent group (can contain operators)
- **2** - Base group (root level, typically only one)

### Hierarchy Example
```
Base Operator Group (ID: 1, IsParent: 2)
  ├─ Management (ID: 5, IsParent: 1)
  │   ├─ Manager (OpNumber: 1201)
  │   └─ Barry (OpNumber: 1525)
  ├─ Staff (ID: 7, IsParent: 1)
  │   └─ T/A Till 1 (OpNumber: 1)
  └─ Support Staff (ID: 2, IsParent: 1)
      └─ Support (OpNumber: 3206)
```

## How to Use

### Step 1: Prepare CSV File
Create a CSV file with operator information following the format above.

### Step 2: Launch Tool
Run `deploy-main.bat` or `deploy-dev.bat` and select:
```
[1] Operator Management
  > [1] Bulk Operations
    > [1] Bulk Add Operators
```

### Step 3: Select Parent Group
Choose the parent group/security level for the operators:
- **[BASE]** - Root level group
- **[GROUP]** - Parent group (e.g., Management, Staff, Supervisor)

### Step 4: Load CSV
- Click **Browse** to select your CSV file
- Review the operator list in the grid
- Verify OpNumbers are valid (4 digits)

### Step 5: Configure Options
- ☑️ **Update existing operators** - If OpNumber exists, update instead of error
- ☑️ **Use Parent Settings** - Inherit permissions from parent group (recommended)

### Step 6: Execute
Click **Add Operators** to process:
- New operators will be created
- Existing operators will be updated (if option enabled)
- Status column shows success/error for each operator
- Summary shows counts: Added, Updated, Errors

## Database Fields

### Required Fields (Auto-populated)
- `OperatorID` - Auto-generated (IDENTITY)
- `FirstName` - From CSV
- `LastName` - From CSV
- `OpNumber` - From CSV or auto-generated
- `Password` - From CSV or default "1234"
- `ParentID` - Selected parent group
- `IsParent` - Set to 0 (operator)
- `UseParentSettings` - From checkbox option
- `Inactive` - Set to 0 (active)
- `DateUpdated` - Current timestamp
- `DateTimeCreated` - Current timestamp
- `AddressID` - Set to 0
- `CommentId` - Set to 0
- `AllowedVenueID` - Set to 0

### Validation Rules
1. **OpNumber must be 4 digits** - Auto-regenerated if invalid
2. **OpNumber must be unique** - Checked against existing operators
3. **FirstName & LastName required** - Rows skipped if missing
4. **ParentID must exist** - Selected from valid parent groups

## Tips & Best Practices

### OpNumber Management
- Use ranges for different groups:
  - 1000-1999: Staff
  - 2000-2999: Management
  - 3000-3999: Support
  - 9000-9999: Admin/Special

### Security
- Default password "1234" should be changed on first login
- Consider using stronger default passwords in CSV
- Use Parent Settings to simplify permission management

### Bulk Operations
- Test with small CSV first (5-10 operators)
- Keep backups of CSV files for reference
- Use meaningful names (FirstName + LastName)
- Avoid special characters in names

### Error Handling
- Check Status column for each operator
- Common errors:
  - Duplicate OpNumber (enable "Update existing" to fix)
  - Invalid CSV format (check column names)
  - Database connection issues (verify registry settings)

## Troubleshooting

### "OpNumber already exists"
- **Solution 1**: Enable "Update existing operators" checkbox
- **Solution 2**: Remove OpNumber from CSV (auto-generate)
- **Solution 3**: Change OpNumber to unique value

### "No parent groups found"
- **Cause**: Database has no parent groups (IsParent = 1 or 2)
- **Solution**: Create parent groups first using BEPOZ Backoffice

### "CSV file not found"
- **Cause**: File path incorrect or file moved
- **Solution**: Browse to correct file location

### "Invalid CSV format"
- **Cause**: Missing columns or incorrect headers
- **Solution**: Verify column names match exactly: `FirstName,LastName,OpNumber,Password`

## Sample CSV Files

Located in repository root:
- `sample-operators.csv` - Example with various scenarios

## Logging

All operations logged to: `C:\Bepoz\Toolkit\Logs\BulkAddOperators_YYYYMMDD.log`

Log entries include:
- CSV file loaded
- Operators added/updated
- Errors and exceptions
- Parent group selected
- Execution summary

## Version History

### v1.0.0 (2026-02-17)
- Initial release
- CSV import
- Auto-generate OpNumbers
- Parent group assignment
- Update existing operators
- Use parent settings option
