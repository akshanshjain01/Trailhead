/**
 * Unit tests for AccountDatatableController.
 * Covers getAccounts, updateAccounts, deleteAccounts — positive, negative, and bulk paths.
 */
@IsTest
private class AccountDatatableControllerTest {

    private static final Integer BULK_COUNT = 251;

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAccounts(BULK_COUNT, true);
    }

    // ─── getAccounts ─────────────────────────────────────────────────────────

    @IsTest
    static void shouldReturnAccounts_WhenDefaultParams() {
        Test.startTest();
        Map<String, Object> result = AccountDatatableController.getAccounts(null, null, null, null);
        Test.stopTest();

        List<Account> records = (List<Account>) result.get('records');
        Integer totalCount    = (Integer) result.get('totalCount');

        Assert.isNotNull(records, 'records should not be null');
        Assert.areEqual(50, records.size(), 'default limit should return 50 records');
        Assert.areEqual(BULK_COUNT, totalCount, 'totalCount should equal all inserted accounts');
    }

    @IsTest
    static void shouldReturnMaxRecords_WhenLimitSetToBulkCount() {
        Test.startTest();
        Map<String, Object> result = AccountDatatableController.getAccounts(BULK_COUNT, 0, 'Name', 'asc');
        Test.stopTest();

        List<Account> records = (List<Account>) result.get('records');
        // Controller caps at MAX_LIMIT (200); requesting 251 returns 200
        Assert.areEqual(200, records.size(), 'should return at most 200 records (MAX_LIMIT cap)');
    }

    @IsTest
    static void shouldCapLimit_WhenLimitExceedsMax() {
        Test.startTest();
        Map<String, Object> result = AccountDatatableController.getAccounts(9999, 0, 'Name', 'asc');
        Test.stopTest();

        List<Account> records = (List<Account>) result.get('records');
        Assert.isTrue(records.size() <= 200, 'result size should not exceed the 200-record cap');
    }

    @IsTest
    static void shouldRespectOffset_WhenOffsetProvided() {
        Test.startTest();
        Map<String, Object> page1 = AccountDatatableController.getAccounts(50, 0,   'Name', 'asc');
        Map<String, Object> page2 = AccountDatatableController.getAccounts(50, 50,  'Name', 'asc');
        Test.stopTest();

        List<Account> records1 = (List<Account>) page1.get('records');
        List<Account> records2 = (List<Account>) page2.get('records');

        Assert.areEqual(50, records1.size(), 'page 1 should have 50 records');
        Assert.areEqual(50, records2.size(), 'page 2 should have 50 records');
        Assert.areNotEqual(records1[0].Id, records2[0].Id, 'pages should not start on the same record');
    }

    @IsTest
    static void shouldSortDescending_WhenSortDirectionIsDesc() {
        Test.startTest();
        Map<String, Object> result = AccountDatatableController.getAccounts(200, 0, 'AnnualRevenue', 'desc');
        Test.stopTest();

        List<Account> records = (List<Account>) result.get('records');
        Assert.isTrue(
            records[0].AnnualRevenue >= records[records.size() - 1].AnnualRevenue,
            'records should be sorted by AnnualRevenue descending'
        );
    }

    @IsTest
    static void shouldDefaultSortToName_WhenInvalidSortFieldProvided() {
        Test.startTest();
        Map<String, Object> result = AccountDatatableController.getAccounts(50, 0, 'INVALID_FIELD__c', 'asc');
        Test.stopTest();

        List<Account> records = (List<Account>) result.get('records');
        Assert.isNotNull(records, 'should return records even with invalid sort field');
    }

    // ─── updateAccounts ──────────────────────────────────────────────────────

    @IsTest
    static void shouldUpdateAccounts_WhenValidRecordsProvided() {
        List<Account> accounts = [SELECT Id, Industry FROM Account LIMIT 5];
        for (Account acc : accounts) {
            acc.Industry = 'Healthcare';
        }

        Test.startTest();
        AccountDatatableController.updateAccounts(accounts);
        Test.stopTest();

        List<Account> updated = [SELECT Id, Industry FROM Account WHERE Id IN :accounts];
        for (Account acc : updated) {
            Assert.areEqual('Healthcare', acc.Industry, 'Industry should be updated to Healthcare');
        }
    }

    @IsTest
    static void shouldDoNothing_WhenUpdateCalledWithEmptyList() {
        Test.startTest();
        AccountDatatableController.updateAccounts(new List<Account>());
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Account];
        Assert.areEqual(BULK_COUNT, count, 'no records should be affected by an empty update');
    }

    @IsTest
    static void shouldDoNothing_WhenUpdateCalledWithNull() {
        Test.startTest();
        AccountDatatableController.updateAccounts(null);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Account];
        Assert.areEqual(BULK_COUNT, count, 'no records should be affected by a null update');
    }

    // ─── deleteAccounts ──────────────────────────────────────────────────────

    @IsTest
    static void shouldDeleteAccounts_WhenValidIdsProvided() {
        List<Account> toDelete = [SELECT Id FROM Account LIMIT 3];
        List<Id> idsToDelete = new List<Id>();
        for (Account acc : toDelete) {
            idsToDelete.add(acc.Id);
        }

        Test.startTest();
        AccountDatatableController.deleteAccounts(idsToDelete);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM Account WHERE Id IN :idsToDelete];
        Assert.areEqual(0, remaining, 'deleted accounts should no longer exist');

        Integer total = [SELECT COUNT() FROM Account];
        Assert.areEqual(BULK_COUNT - 3, total, 'total count should decrease by 3');
    }

    @IsTest
    static void shouldDoNothing_WhenDeleteCalledWithEmptyList() {
        Test.startTest();
        AccountDatatableController.deleteAccounts(new List<Id>());
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Account];
        Assert.areEqual(BULK_COUNT, count, 'no records should be deleted for an empty list');
    }

    @IsTest
    static void shouldDoNothing_WhenDeleteCalledWithNull() {
        Test.startTest();
        AccountDatatableController.deleteAccounts(null);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Account];
        Assert.areEqual(BULK_COUNT, count, 'no records should be deleted for a null input');
    }
}
