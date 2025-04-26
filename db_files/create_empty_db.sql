-- 創建比賽表
CREATE TABLE competitions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  venue TEXT,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  status TEXT NOT NULL,
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- 創建參與者表
CREATE TABLE participants (
  id TEXT PRIMARY KEY,
  competition_id TEXT NOT NULL,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  school TEXT,
  FOREIGN KEY (competition_id) REFERENCES competitions (id)
); 