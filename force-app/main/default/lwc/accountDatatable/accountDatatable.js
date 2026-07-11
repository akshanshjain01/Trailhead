import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getAccounts from '@salesforce/apex/AccountDatatableController.getAccounts';
import updateAccounts from '@salesforce/apex/AccountDatatableController.updateAccounts';
import deleteAccounts from '@salesforce/apex/AccountDatatableController.deleteAccounts';

const ROW_ACTIONS = [
    { label: 'View', name: 'view' },
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' }
];

const COLUMNS = [
    {
        label: 'Account Name',
        fieldName: 'nameUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' },
        sortable: true
    },
    { label: 'Industry', fieldName: 'Industry', type: 'text', sortable: true, editable: true },
    {
        label: 'Annual Revenue',
        fieldName: 'AnnualRevenue',
        type: 'currency',
        typeAttributes: { currencyCode: 'USD', minimumFractionDigits: 0 },
        sortable: true,
        editable: true,
        cellAttributes: { alignment: 'right' }
    },
    { label: 'Phone', fieldName: 'Phone', type: 'phone', editable: true },
    {
        label: 'Created Date',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' },
        sortable: true
    },
    { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

export default class AccountDatatable extends NavigationMixin(LightningElement) {
    @api maxRows = 50;
    @api enableInfiniteScroll = false;
    @api showRowNumbers = false;

    columns = COLUMNS;
    @track data = [];
    error;
    isLoading = true;

    sortBy = 'Name';
    sortDirection = 'asc';
    selectedRows = [];
    draftValues = [];

    offset = 0;
    totalRecords = 0;

    _wiredResult;

    @wire(getAccounts, {
        limitSize: '$maxRows',
        offset: '$offset',
        sortBy: '$sortBy',
        sortDirection: '$sortDirection'
    })
    wiredAccounts(result) {
        this._wiredResult = result;
        this.isLoading = false;
        const { data, error } = result;

        if (data) {
            this.data = data.records.map(rec => ({ ...rec, nameUrl: `/${rec.Id}` }));
            this.totalRecords = data.totalCount;
            this.error = undefined;
        } else if (error) {
            this.error = this._reduceErrors(error);
            this.data = [];
        }
    }

    get hasData() {
        return this.data.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && this.data.length === 0 && !this.error;
    }

    get hasSelection() {
        return this.selectedRows.length > 0;
    }

    get noSelection() {
        return this.selectedRows.length === 0;
    }

    get selectedCount() {
        return this.selectedRows.length;
    }

    get selectedRowIds() {
        return this.selectedRows.map(r => r.Id);
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.isLoading = true;
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    handleCellChange(event) {
        this.draftValues = event.detail.draftValues;
    }

    async handleSave(event) {
        this.isLoading = true;
        try {
            await updateAccounts({ records: event.detail.draftValues });
            this.draftValues = [];
            this._toast('Success', 'Records updated', 'success');
            await this._refresh();
        } catch (e) {
            this._toast('Error', this._reduceErrors(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.draftValues = [];
    }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;

        if (name === 'view') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: row.Id, objectApiName: 'Account', actionName: 'view' }
            });
        } else if (name === 'edit') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: row.Id, objectApiName: 'Account', actionName: 'edit' }
            });
        } else if (name === 'delete') {
            this._deleteRows([row.Id], `Delete ${row.Name}?`);
        }
    }

    async handleBulkDelete() {
        if (!this.hasSelection) return;
        const ids = this.selectedRowIds;
        await this._deleteRows(ids, `Delete ${ids.length} record(s)?`);
        this.selectedRows = [];
    }

    handleRefresh() {
        this._refresh();
    }

    loadMoreData(event) {
        if (!this.enableInfiniteScroll) return;
        const table = event.target;

        if (this.data.length >= this.totalRecords) {
            table.enableInfiniteLoading = false;
            table.isLoading = false;
            return;
        }

        this.offset = this.data.length;
    }

    async _deleteRows(ids, confirmMessage) {
        // eslint-disable-next-line no-alert
        if (!confirm(confirmMessage)) return;
        this.isLoading = true;
        try {
            await deleteAccounts({ recordIds: ids });
            this._toast('Success', `${ids.length} record(s) deleted`, 'success');
            await this._refresh();
        } catch (e) {
            this._toast('Error', this._reduceErrors(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async _refresh() {
        this.isLoading = true;
        await refreshApex(this._wiredResult);
        this.isLoading = false;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _reduceErrors(errors) {
        if (!Array.isArray(errors)) errors = [errors];
        return errors
            .filter(Boolean)
            .map(e => e?.body?.message ?? e?.message ?? JSON.stringify(e))
            .join(', ');
    }
}
