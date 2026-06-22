package database

import (
	"database/sql"
	"encoding/json"
	"strings"
)

func rowsToJSON(rows *sql.Rows) string {
	cols, err := rows.Columns()
	if err != nil {
		Log("[DB] rowsToJSON Columns() error: %v", err)
		return "[]"
	}
	var results []map[string]interface{}
	for rows.Next() {
		vals := make([]interface{}, len(cols))
		valPtrs := make([]interface{}, len(cols))
		for i := range vals {
			valPtrs[i] = &vals[i]
		}
		if err := rows.Scan(valPtrs...); err != nil {
			Log("[DB] rowsToJSON Scan() error: %v", err)
			continue
		}
		row := make(map[string]interface{})
		for i, col := range cols {
			if vals[i] != nil {
				switch v := vals[i].(type) {
				case []byte:
					row[col] = string(v)
				default:
					row[col] = v
				}
			}
		}
		results = append(results, row)
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, err := json.Marshal(results)
	if err != nil {
		Log("[DB] rowsToJSON Marshal() error: %v", err)
		return "[]"
	}
	return string(out)
}

var Log = func(format string, args ...interface{}) {}

func SetLogger(logFn func(format string, args ...interface{})) {
	Log = logFn
}

func ExecWithPlaceholders(db *sql.DB, query string, items []string) (int, error) {
	if len(items) == 0 {
		return 0, nil
	}
	placeholders := make([]string, len(items))
	args := make([]interface{}, len(items))
	for i, item := range items {
		placeholders[i] = "?"
		args[i] = item
	}
	res, err := db.Exec(strings.Replace(query, "?", strings.Join(placeholders, ","), 1), args...)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return int(n), nil
}
