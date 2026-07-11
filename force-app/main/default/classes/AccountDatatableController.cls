/**
 * AuraEnabled controller backing the accountDatatable LWC.
 * Provides paginated, sortable Account queries and lightweight update/delete operations.
 */
public with sharing class AccountDatatableController {

    private static final Integer DEFAULT_LIMIT = 50;
    private static final Integer MAX_LIMIT = 200;
    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        'Name', 'Industry', 'AnnualRevenue', 'Phone', 'CreatedDate'
    };
    private static final Set<String> SORT_DIRECTIONS = new Set<String>{ 'asc', 'desc' };

    // ─── Query ───────────────────────────────────────────────────────────────

    /**
     * Returns a page of Account records with a total count for pagination.
     * @param limitSize  Maximum rows to return (capped at 200)
     * @param offset     Zero-based row offset for pagination
     * @param sortBy     API field name to sort by (defaults to Name)
     * @param sortDirection  'asc' or 'desc' (defaults to asc)
     * @return Map with keys: records (List<Account>), totalCount (Integer)
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAccounts(
        Integer limitSize,
        Integer offset,
        String sortBy,
        String sortDirection
    ) {
        Integer safeLimit = (limitSize == null || limitSize <= 0)
            ? DEFAULT_LIMIT
            : Math.min(limitSize, MAX_LIMIT);
        Integer safeOffset = (offset == null || offset < 0) ? 0 : offset;
        String safeSort = SORTABLE_FIELDS.contains(sortBy) ? sortBy : 'Name';
        String safeDirn = SORT_DIRECTIONS.contains(sortDirection?.toLowerCase())
            ? sortDirection.toLowerCase()
            : 'asc';

        // Dynamic sort direction is not supported in bind-variable SOQL;
        // split into two branches using the validated allowlist values.
        // AccessLevel.USER_MODE on queryWithBinds enforces CRUD/FLS — WITH USER_MODE
        // cannot also appear in the query string when using that overload.
        String sortClause = safeSort + (safeDirn == 'desc' ? ' DESC' : ' ASC') + ' NULLS LAST';
        List<Account> records = Database.queryWithBinds(
            'SELECT Id, Name, Industry, AnnualRevenue, Phone, CreatedDate'
            + ' FROM Account'
            + ' ORDER BY ' + sortClause
            + ' LIMIT :safeLimit OFFSET :safeOffset',
            new Map<String, Object>{ 'safeLimit' => safeLimit, 'safeOffset' => safeOffset },
            AccessLevel.USER_MODE
        );

        Integer totalCount = [SELECT COUNT() FROM Account];

        return new Map<String, Object>{
            'records'    => records,
            'totalCount' => totalCount
        };
    }

    // ─── Update ──────────────────────────────────────────────────────────────

    /**
     * Saves inline-edited Account field changes from the datatable draft values.
     * @param records List of partial Account records (must include Id)
     * @throws AuraHandledException on DML failure
     */
    @AuraEnabled
    public static void updateAccounts(List<Account> records) {
        if (records == null || records.isEmpty()) {
            return;
        }
        try {
            update as user records;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    // ─── Delete ──────────────────────────────────────────────────────────────

    /**
     * Deletes a list of Accounts by Id.
     * @param recordIds List of Account Ids to delete
     * @throws AuraHandledException on DML failure
     */
    @AuraEnabled
    public static void deleteAccounts(List<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }
        List<Account> toDelete = new List<Account>();
        for (Id accountId : recordIds) {
            toDelete.add(new Account(Id = accountId));
        }
        try {
            delete as user toDelete;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
}
