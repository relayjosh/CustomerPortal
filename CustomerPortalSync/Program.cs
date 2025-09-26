using System;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;

namespace CustomerPortalSync
{
    class Program
    {
        // Connection strings - update these with your actual server names
        private static readonly string erpConnectionString = 
            "Server=vmi1002374;Database=epds01;Integrated Security=true;TrustServerCertificate=true;";
        
        private static readonly string mirrorConnectionString = 
            "Server=localhost\\SQLEXPRESS;Database=CustomerPortalMirror;Integrated Security=true;TrustServerCertificate=true;";

        static async Task Main(string[] args)
        {
            Console.WriteLine($"CustomerPortal Sync Started: {DateTime.Now}");
            
            try
            {
                await SyncCustomers();
                await SyncOrderHeaders();
                await SyncOrderDetails();
                
                Console.WriteLine($"Sync Completed Successfully: {DateTime.Now}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Sync Failed: {ex.Message}");
                Console.WriteLine($"Stack Trace: {ex.StackTrace}");
            }
            
            if (args.Length == 0)
            {
                Console.WriteLine("Press any key to exit...");
                Console.ReadKey();
            }
        }

        private static async Task SyncCustomers()
        {
            Console.WriteLine("Syncing customers...");
            
            string erpQuery = @"
                SELECT cust_no, cust_name, cust_addr1, cust_addr2, cust_city, 
                       cust_state, cust_zip, cust_phone, active
                FROM customer 
                WHERE active = 1";

            string deleteQuery = "DELETE FROM customer";
            
            string insertQuery = @"
                INSERT INTO customer (cust_no, cust_name, cust_addr1, cust_addr2, 
                                    cust_city, cust_state, cust_zip, cust_phone, active, sync_date)
                VALUES (@cust_no, @cust_name, @cust_addr1, @cust_addr2, 
                        @cust_city, @cust_state, @cust_zip, @cust_phone, @active, GETDATE())";

            using var erpConnection = new SqlConnection(erpConnectionString);
            using var mirrorConnection = new SqlConnection(mirrorConnectionString);
            
            await erpConnection.OpenAsync();
            await mirrorConnection.OpenAsync();

            // Clear existing data (full refresh approach)
            using var deleteCommand = new SqlCommand(deleteQuery, mirrorConnection);
            await deleteCommand.ExecuteNonQueryAsync();

            // Read from ERP and insert into mirror
            using var selectCommand = new SqlCommand(erpQuery, erpConnection);
            using var reader = await selectCommand.ExecuteReaderAsync();
            
            int customerCount = 0;
            while (await reader.ReadAsync())
            {
                using var insertCommand = new SqlCommand(insertQuery, mirrorConnection);
                
                insertCommand.Parameters.AddWithValue("@cust_no", reader["cust_no"]);
                insertCommand.Parameters.AddWithValue("@cust_name", reader["cust_name"]);
                insertCommand.Parameters.AddWithValue("@cust_addr1", reader["cust_addr1"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@cust_addr2", reader["cust_addr2"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@cust_city", reader["cust_city"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@cust_state", reader["cust_state"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@cust_zip", reader["cust_zip"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@cust_phone", reader["cust_phone"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@active", reader["active"]);
                
                await insertCommand.ExecuteNonQueryAsync();
                customerCount++;
            }
            
            Console.WriteLine($"Synced {customerCount} customers");
        }

        private static async Task SyncOrderHeaders()
        {
            Console.WriteLine("Syncing order headers...");
            
            string erpQuery = @"
                SELECT order_no, ord_type, order_dt, cust_no, cust_po, buyer,
                       ship_via, ship_date, ship_no, inv_no, inv_date, status,
                       freight, tax_amt
                FROM ord_hedr 
                WHERE order_dt >= DATEADD(YEAR, -2, GETDATE())
                ORDER BY order_no";

            string deleteQuery = "DELETE FROM ord_hedr";
            
            string insertQuery = @"
                INSERT INTO ord_hedr (order_no, ord_type, order_dt, cust_no, cust_po, buyer,
                                    ship_via, ship_date, ship_no, inv_no, inv_date, status,
                                    freight, tax_amt, sync_date)
                VALUES (@order_no, @ord_type, @order_dt, @cust_no, @cust_po, @buyer,
                        @ship_via, @ship_date, @ship_no, @inv_no, @inv_date, @status,
                        @freight, @tax_amt, GETDATE())";

            using var erpConnection = new SqlConnection(erpConnectionString);
            using var mirrorConnection = new SqlConnection(mirrorConnectionString);
            
            await erpConnection.OpenAsync();
            await mirrorConnection.OpenAsync();

            // Clear existing data
            using var deleteCommand = new SqlCommand(deleteQuery, mirrorConnection);
            await deleteCommand.ExecuteNonQueryAsync();

            // Read from ERP and insert into mirror
            using var selectCommand = new SqlCommand(erpQuery, erpConnection);
            using var reader = await selectCommand.ExecuteReaderAsync();
            
            int orderCount = 0;
            while (await reader.ReadAsync())
            {
                using var insertCommand = new SqlCommand(insertQuery, mirrorConnection);
                
                insertCommand.Parameters.AddWithValue("@order_no", reader["order_no"]);
                insertCommand.Parameters.AddWithValue("@ord_type", reader["ord_type"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@order_dt", reader["order_dt"]);
                insertCommand.Parameters.AddWithValue("@cust_no", reader["cust_no"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@cust_po", reader["cust_po"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@buyer", reader["buyer"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@ship_via", reader["ship_via"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@ship_date", reader["ship_date"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@ship_no", reader["ship_no"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@inv_no", reader["inv_no"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@inv_date", reader["inv_date"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@status", reader["status"]);
                insertCommand.Parameters.AddWithValue("@freight", reader["freight"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@tax_amt", reader["tax_amt"] ?? DBNull.Value);
                
                await insertCommand.ExecuteNonQueryAsync();
                orderCount++;
            }
            
            Console.WriteLine($"Synced {orderCount} order headers");
        }

        private static async Task SyncOrderDetails()
        {
            Console.WriteLine("Syncing order details...");
            
            string erpQuery = @"
                SELECT od.order_no, od.lin_no, od.manu_no, od.item_no, od.cust_itmno,
                       od.item_desc, od.item_desc2, od.ord_qty, od.qty_shipd, od.bal_of_ord,
                       od.unit_price, od.due_date, od.status
                FROM ord_detl od
                JOIN ord_hedr oh ON od.order_no = oh.order_no
                WHERE oh.order_dt >= DATEADD(YEAR, -2, GETDATE())
                ORDER BY od.order_no, od.lin_no";

            string deleteQuery = "DELETE FROM ord_detl";
            
            string insertQuery = @"
                INSERT INTO ord_detl (order_no, lin_no, manu_no, item_no, cust_itmno,
                                    item_desc, item_desc2, ord_qty, qty_shipd, bal_of_ord,
                                    unit_price, due_date, status, sync_date)
                VALUES (@order_no, @lin_no, @manu_no, @item_no, @cust_itmno,
                        @item_desc, @item_desc2, @ord_qty, @qty_shipd, @bal_of_ord,
                        @unit_price, @due_date, @status, GETDATE())";

            using var erpConnection = new SqlConnection(erpConnectionString);
            using var mirrorConnection = new SqlConnection(mirrorConnectionString);
            
            await erpConnection.OpenAsync();
            await mirrorConnection.OpenAsync();

            // Clear existing data
            using var deleteCommand = new SqlCommand(deleteQuery, mirrorConnection);
            await deleteCommand.ExecuteNonQueryAsync();

            // Read from ERP and insert into mirror
            using var selectCommand = new SqlCommand(erpQuery, erpConnection);
            using var reader = await selectCommand.ExecuteReaderAsync();
            
            int detailCount = 0;
            while (await reader.ReadAsync())
            {
                using var insertCommand = new SqlCommand(insertQuery, mirrorConnection);
                
                insertCommand.Parameters.AddWithValue("@order_no", reader["order_no"]);
                insertCommand.Parameters.AddWithValue("@lin_no", reader["lin_no"]);
                insertCommand.Parameters.AddWithValue("@manu_no", reader["manu_no"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@item_no", reader["item_no"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@cust_itmno", reader["cust_itmno"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@item_desc", reader["item_desc"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@item_desc2", reader["item_desc2"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@ord_qty", reader["ord_qty"]);
                insertCommand.Parameters.AddWithValue("@qty_shipd", reader["qty_shipd"]);
                insertCommand.Parameters.AddWithValue("@bal_of_ord", reader["bal_of_ord"]);
                insertCommand.Parameters.AddWithValue("@unit_price", reader["unit_price"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@due_date", reader["due_date"] ?? DBNull.Value);
                insertCommand.Parameters.AddWithValue("@status", reader["status"]);
                
                await insertCommand.ExecuteNonQueryAsync();
                detailCount++;
            }
            
            Console.WriteLine($"Synced {detailCount} order detail lines");
        }
    }
}