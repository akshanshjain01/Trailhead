/**
 * Central factory for creating test SObject records.
 * All test classes must use this factory instead of building records inline.
 */
@IsTest
public class TestDataFactory {

    /**
     * Creates and optionally inserts a list of Account records.
     * @param count      Number of accounts to create
     * @param doInsert   Whether to insert records into the database
     * @return List of Account records
     */
    public static List<Account> createAccounts(Integer count, Boolean doInsert) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(
                Name            = 'Test Account ' + i,
                Industry        = 'Technology',
                AnnualRevenue   = 100000 + (i * 1000),
                Phone           = '555-000-' + String.valueOf(i).leftPad(4, '0')
            ));
        }
        if (doInsert) {
            insert accounts;
        }
        return accounts;
    }
}
