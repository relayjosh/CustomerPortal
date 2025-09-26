using System;
using System.Collections.Generic;
using System.Data.Odbc;

namespace CustomerPortalSync
{
    class Program
    {
        // ODBC connection strings
        private static readonly string erpConnectionString = 
            "Driver={SQL Server};Server=vmi1002374;Database=epds01;Trusted_Connection=yes;";
        
        private static readonly string mirrorConnectionString = 
            "Driver={SQL Server};Server=localhost\\SQLEXPRESS;Database=CustomerPortalMirror;Trusted_Connection=yes;";

        static void Main(string[] args)
        {
            Console.WriteLine($"CustomerPortal Sync Started: {DateTime.Now}");
            
            try
            {
                TestConnections();
                SyncCustomers();
                Console.WriteLine($"Sync Completed Successfully: {DateTime.Now}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Sync Failed: {ex.Message}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"Inner Exception: {ex.InnerException.Message}");
                }
            }
            
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }

        private static void TestConnections()
        {
            Console.WriteLine("Testing ERP database connection...");
            using var erpConnection = new OdbcConnection(erpConnectionString);
            erpConnection.Open();
            
            using var cmd = new OdbcCommand("SELECT COUNT(*) FROM customer WHERE active = 1", erpConnection);
            var result = cmd.ExecuteScalar();
            Console.WriteLine($"ERP Connection OK - Found {result} active customers");
            
            Console.WriteLine("Testing Mirror database connection...");
            using var mirrorConnection = new OdbcConnection(mirrorConnectionString);
            mirrorConnection.Open();
            
            using var cmd2 = new OdbcCommand("SELECT COUNT(*) FROM customer", mirrorConnection);
            var result2 = cmd2.ExecuteScalar();
            Console.WriteLine($"Mirror Connection OK - Currently has {result2} customers");
        }

        private static void SyncCustomers()
        {
            Console.WriteLine("Starting customer sync...");
            
            // Get data from ERP
            var customers = new List<(string cust_no, string cust_name, string cust_city, string cust_state, bool active)>();
            
            using var erpConnection = new OdbcConnection(erpConnectionString);
            erpConnection.Open();
            
            using var selectCmd = new OdbcCommand(@"
                SELECT TOP 10 cust_no, cust_name, cust_city, cust_state, active 
                FROM customer 
                WHERE active = 1 
                ORDER BY cust_no", erpConnection);
            
            using var reader = selectCmd.ExecuteReader();
            while (reader.Read())
            {
                customers.Add((
                    reader["cust_no"]?.ToString()?.Trim() ?? "",
                    reader["cust_name"]?.ToString()?.Trim() ?? "",
                    reader["cust_city"]?.ToString()?.Trim() ?? "",
                    reader["cust_state"]?.ToString()?.Trim() ?? "",
                    Convert.ToBoolean(reader["active"])
                ));
            }
            
            Console.WriteLine($"Retrieved {customers.Count} customers from ERP");
            
            // Sync to mirror database
            using var mirrorConnection = new OdbcConnection(mirrorConnectionString);
            mirrorConnection.Open();
            
            // Clear existing data
            using var deleteCmd = new OdbcCommand("DELETE FROM customer", mirrorConnection);
            int deleted = deleteCmd.ExecuteNonQuery();
            Console.WriteLine($"Cleared {deleted} existing customers");
            
            // Insert new data
            int inserted = 0;
            foreach (var customer in customers)
            {
                using var insertCmd = new OdbcCommand(@"
                    INSERT INTO customer (cust_no, cust_name, cust_city, cust_state, active, sync_date)
                    VALUES (?, ?, ?, ?, ?, GETDATE())", mirrorConnection);
                
                insertCmd.Parameters.Add(new OdbcParameter("cust_no", customer.cust_no));
                insertCmd.Parameters.Add(new OdbcParameter("cust_name", customer.cust_name));
                insertCmd.Parameters.Add(new OdbcParameter("cust_city", customer.cust_city));
                insertCmd.Parameters.Add(new OdbcParameter("cust_state", customer.cust_state));
                insertCmd.Parameters.Add(new OdbcParameter("active", customer.active));
                
                insertCmd.ExecuteNonQuery();
                inserted++;
            }
            
            Console.WriteLine($"Inserted {inserted} customers into mirror database");
        }
    }
}