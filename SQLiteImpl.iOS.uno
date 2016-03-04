using Fuse;
using Fuse.Controls;
using Fuse.Scripting;
using Fuse.Reactive;
using ObjC;

using Uno;
using Uno.Collections;

using Uno.Compiler.ExportTargetInterop;
using iOS.Foundation;
// http://www.appcoda.com/sqlite-database-ios-app-tutorial/

[TargetSpecificImplementation]
public extern(iOS) static class SQLiteImpl {

	static Dictionary<string,ObjC.ID> dbs = new Dictionary<string,ObjC.ID>();

	[Require("Source.Include", "sqlite3.h")]
	[Require("LinkLibrary", "sqlite3")]
	[Foreign(Language.ObjC)]
	public static extern ObjC.ID OpenImplNative(string filename)
	@{
		sqlite3 *sqlite3Database;
		BOOL openDatabaseResult = sqlite3_open([filename UTF8String], &sqlite3Database);
		return (::id)sqlite3Database;
	@}

	public static object OpenImpl(string filename) {
		if (dbs.ContainsKey(filename)) {
		   return filename;
		}
		var db = OpenImplNative(filename);
		dbs.Add(filename, db);
		return filename;
	}

	// TODO: Throw errors
	[Foreign(Language.ObjC)]
	public static extern void ExecImplNative(ObjC.ID db, string statement, string[] param)
	@{
		BOOL isSuccess = YES;
		char *errMsg;
		sqlite3_stmt *compiledStatement;

        if (sqlite3_prepare_v2((sqlite3 *)db, [statement UTF8String], -1, &compiledStatement, NULL) != SQLITE_OK) {
		    // NSLog(@"Prepare failure: %s", sqlite3_errmsg((sqlite3 *)db));
		}
		for (int i=0; i<param.count; i++) {
			if (sqlite3_bind_text(compiledStatement, i + 1, [param[i] UTF8String], -1, NULL) != SQLITE_OK) {
			    NSLog(@"Bind %d failure: %s", i, sqlite3_errmsg((sqlite3 *)db));
			    return;
			}
		}
		if (sqlite3_step(compiledStatement) != SQLITE_DONE) {
		    NSLog(@"Step failure: %s", sqlite3_errmsg((sqlite3 *)db));
		    return;
		}
		sqlite3_finalize(compiledStatement);
		return;
	@}

	public static void ExecImpl(string handler, string statement, string[] param) {
		var db = dbs[handler];
		ExecImplNative(db, statement, param);
	}

	[Foreign(Language.ObjC)]
	public static extern void CloseImplNative(ObjC.ID db)
	@{
		sqlite3_close((sqlite3 *)db);
		return;
	@}

	public static void CloseImpl(string handler) {
		var db = dbs[handler];
		CloseImplNative(db);
	}

	// TODO: Throw errors
	[Foreign(Language.ObjC)]
	public static extern void QueryImplNative(FuseX.SQLite.JSListDict result, ObjC.ID db, string statement, string[] param)
	@{
		sqlite3_stmt *compiledStatement;
		NSMutableArray *columnNames = [[NSMutableArray alloc] init];

		// Load all data from database to memory.
		BOOL prepareStatementResult = sqlite3_prepare_v2((sqlite3 *)db, [statement UTF8String], -1, &compiledStatement, NULL);
		if(prepareStatementResult != SQLITE_OK) {
		    NSLog(@"Prepare failure: %s", sqlite3_errmsg((sqlite3 *)db));
		    return;
		}
		for (int i=0; i<param.count; i++) {
			if (sqlite3_bind_text(compiledStatement, i + 1, [param[i] UTF8String], -1, NULL) != SQLITE_OK) {
			    NSLog(@"Bind %d failure: %s", i, sqlite3_errmsg((sqlite3 *)db));
			    return;
			}
		}

		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			// Initialize the mutable array that will contain the data of a fetched row.
			@{FuseX.SQLite.JSListDict:Of(result).NewRowSetActive():Call()};

		    // Get the total number of columns.
		    int totalColumns = sqlite3_column_count(compiledStatement);

		    // Go through all columns and fetch each column data.
		    for (int i=0; i<totalColumns; i++){
		        // Convert the column data to text (characters).
		        char *dbDataAsChars;

		        // Keep the current column name.
		        if (columnNames.count != totalColumns) {
		            dbDataAsChars = (char *)sqlite3_column_name(compiledStatement, i);
		            [columnNames addObject:[NSString stringWithUTF8String:dbDataAsChars]];
		        }

		        dbDataAsChars = (char *)sqlite3_column_text(compiledStatement, i);
		        // If there are contents in the currenct column (field) then add them to the current row array.
		        if (dbDataAsChars != NULL) {
		            // Convert the characters to string.
		            @{FuseX.SQLite.JSListDict:Of(result).SetRow_Column(string,string):Call([columnNames objectAtIndex:i], [NSString stringWithUTF8String:dbDataAsChars])};
		        }

		    }
		}
		[columnNames release];
	@}

	public static void QueryImpl(FuseX.SQLite.JSListDict ld, string handler, string statement, string[] param) {
		var db = dbs[handler];
		QueryImplNative(ld, db, statement, param);
	}
}
