# Customer Portal - ERP Data Integration

A system to provide BigCommerce customers access to their ERP data (orders, shipments, invoices, quotes) through a customer portal integration.

## Architecture Overview

```
ERP Database (vmi1002374)
       ↓ [PowerShell Sync - Every 15min]
Mirror Database (localhost\SQLEXPRESS)
       ↓ [REST API]
BigCommerce Storefront
```

**Core Components:**
- **ERP Database**: Source of truth (SQL Server on vmi1002374)
- **Mirror Database**: Read-only copy for customer portal (SQL Server Express)
- **Sync Service**: PowerShell scripts for data synchronization
- **Web API**: REST endpoints for BigCommerce integration (planned)
- **BigCommerce Integration**: Theme modifications for customer account area (planned)

## Project Structure

```
CustomerPortal/
├── README.md
├── CustomerPortal.sln
├── CustomerPortalSync/           # Data synchronization
│   ├── sync.ps1                 # Connection testing
│   ├── customer-sync.ps1        # Basic customer sync
│   ├── customer-sync-batched.ps1 # Production customer sync
│   ├── order-sync-fixed.ps1     # Order sync with FK handling
│   ├── CustomerPortalSync.csproj # .NET project (future)
│   └── Program.cs               # .NET sync code (needs packages)
└── CustomerPortalAPI/           # Web API (in development)
    ├── CustomerPortalAPI.csproj
    └── Program.cs
```

## Database Schema

### Mirror Database: `CustomerPortalMirror`

**customer** - Customer master data
```sql
cust_no      CHAR(6) PRIMARY KEY    -- Customer number (links to BigCommerce)
cust_name    CHAR(40)               -- Customer name
cust_addr1   CHAR(50)               -- Address line 1
cust_city    CHAR(30)               -- City
cust_state   CHAR(3)                -- State
cust_zip     CHAR(10)               -- ZIP code
cust_phone   CHAR(20)               -- Phone number
active       BIT                    -- Active status
sync_date    DATETIME               -- Last sync timestamp
```

**ord_hedr** - Order headers
```sql
order_no     INT PRIMARY KEY        -- Order number
ord_type     CHAR(1)                -- Order type
order_dt     DATETIME               -- Order date
cust_no      CHAR(6) → customer     -- Customer FK
cust_po      CHAR(20)               -- Customer PO number
buyer        CHAR(40)               -- Buyer name
ship_via     CHAR(3)                -- Shipping method
ship_date    DATETIME               -- Ship date
inv_no       INT                    -- Invoice number
inv_date     DATETIME               -- Invoice date
status       CHAR(1)                -- Order status (O=Open, C=Complete, V=Void)
freight      NUMERIC(12,2)          -- Freight amount
tax_amt      NUMERIC(12,2)          -- Tax amount
sync_date    DATETIME               -- Last sync timestamp
```

**ord_detl** - Order line items (planned)
```sql
order_no     INT → ord_hedr         -- Order FK
lin_no       NUMERIC(4,0)           -- Line number
item_no      CHAR(25)               -- Item number
item_desc    CHAR(30)               -- Item description
ord_qty      INT                    -- Ordered quantity
qty_shipd    INT                    -- Shipped quantity
unit_price   NUMERIC(12,4)          -- Unit price
status       CHAR(1)                -- Line status
sync_date    DATETIME               -- Last sync timestamp
```

**vw_order_summary** - Pre-aggregated order data for API performance

## Current Status

### ✅ Completed
- **Database Setup**: Mirror database created with proper schema
- **Data Sync**: PowerShell-based synchronization working
- **Customer Data**: 46,336 active customers synced successfully
- **Order Data**: 200+ recent orders synced with proper relationships
- **Error Handling**: Foreign key constraints and data validation working

### 🔄 In Development
- **Web API**: REST endpoints for BigCommerce integration
- **Order Details**: Line-item level synchronization
- **Authentication**: API key validation and CORS setup

### 📋 Planned
- **BigCommerce Integration**: Theme modifications for customer account area
- **Automated Scheduling**: Windows Task Scheduler for sync jobs
- **Production Deployment**: Move from development VM to production server

## Setup Instructions

### Prerequisites
- Windows Server 2022
- SQL Server Express 2022
- PowerShell 5.1+
- .NET 7.0 Runtime
- Network access to ERP database server

### Database Setup

1. **Install SQL Server Express** on development machine
2. **Create mirror database**:
```sql
CREATE DATABASE CustomerPortalMirror;
```

3. **Run schema creation script** (see database schema above)

### Data Synchronization

**Test Connection:**
```powershell
cd CustomerPortalSync
.\sync.ps1
```

**Sync All Customers:**
```powershell
.\customer-sync-batched.ps1
```

**Sync Recent Orders:**
```powershell
.\order-sync-fixed.ps1
```

### Configuration

**Connection Strings:**
- ERP Database: `Server=vmi1002374;Database=epds01;Integrated Security=True;TrustServerCertificate=True;`
- Mirror Database: `Server=localhost\SQLEXPRESS;Database=CustomerPortalMirror;Integrated Security=True;TrustServerCertificate=True;`

**Sync Parameters:**
- Customer batch size: 1,000 records
- Order history: Last 365 days
- Sync frequency: Every 15 minutes (planned)

## Data Synchronization Details

### Customer Sync Process
1. **Full Refresh**: Delete existing customer records
2. **Batched Retrieval**: Process 1,000 customers at a time from ERP
3. **Insert**: Add customers to mirror database with sync timestamp
4. **Progress Reporting**: Display batch progress and completion stats

### Order Sync Process  
1. **Relationship Validation**: Only sync orders for customers that exist in mirror
2. **Date Filtering**: Sync orders from last 365 days
3. **Status Preservation**: Maintain order status codes (O/C/V)
4. **Foreign Key Integrity**: Ensure customer relationships are valid

### Performance Metrics
- **Customer Sync**: ~46,000 customers in approximately 8 minutes
- **Order Sync**: ~200 orders in under 1 minute
- **Batch Size**: 1,000 records optimal for memory usage
- **Error Rate**: 0% with proper FK validation

## API Design (Planned)

### Endpoints

**Customer Orders:**
```
GET /api/v1/orders?customer={erpId}&page=1&pageSize=20
```

**Order Details:**
```
GET /api/v1/orders/{orderId}
```

**Customer Info:**
```
GET /api/v1/customers/{erpId}
```

### Authentication
- API Key required in request headers
- CORS whitelist for BigCommerce domain
- Rate limiting (future enhancement)

### Response Format
```json
{
  "success": true,
  "data": {
    "orders": [...],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 150
    }
  }
}
```

## BigCommerce Integration (Planned)

### Customer Linking Strategy
- Store ERP customer number (`cust_no`) in BigCommerce custom field
- API filters data by customer number for security
- Fallback message for customers without ERP data

### Account Area Integration
- New tabs: Orders, Shipments, Invoices, Quotes
- AJAX calls to API endpoints
- Native BigCommerce styling and user experience

## Development Environment

**Development VM**: VM1100237 (Windows Server 2022)
- SQL Server Express 2022
- SSMS 21
- .NET 7.0 Runtime
- PowerShell 5.1

**ERP Database Server**: vmi1002374 (SQL Server 2022)
- Database: epds01
- Tables: customer, ord_hedr, ord_detl
- Network connectivity established

## Troubleshooting

### Common Issues

**SQL Server Connectivity:**
- Ensure TCP/IP is enabled in SQL Server Configuration Manager
- Verify Windows Firewall allows SQL Server connections
- Use `TrustServerCertificate=True` for SSL issues

**PowerShell Execution Policy:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

**Foreign Key Violations:**
- Run customer sync before order sync
- Verify customer records exist before syncing dependent data

### Performance Optimization
- Use batched processing for large datasets
- Monitor memory usage during sync operations
- Consider incremental sync for frequent updates (future)

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Test changes thoroughly with sample data
4. Commit changes: `git commit -m 'Add new feature'`
5. Push to branch: `git push origin feature/new-feature`
6. Submit pull request

## License

This project is proprietary and confidential.

## Support

For technical issues or questions:
- Review troubleshooting section above
- Check PowerShell execution logs
- Verify database connectivity and permissions
- Ensure all prerequisites are installed correctly