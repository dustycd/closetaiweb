/*
  # Initial Schema Setup

  1. New Tables
    - users
      - id (uuid, primary key)
      - email (text, unique)
      - password_hash (text)
      - name (text)
      - role (text)
      - created_at (timestamp)
      - updated_at (timestamp)
      - deleted_at (timestamp)
    
    - teams
      - id (uuid, primary key)
      - name (text)
      - stripe_customer_id (text)
      - stripe_subscription_id (text)
      - stripe_product_id (text)
      - plan_name (text)
      - subscription_status (text)
      - created_at (timestamp)
      - updated_at (timestamp)
    
    - team_members
      - id (uuid, primary key)
      - team_id (uuid, references teams)
      - user_id (uuid, references users)
      - role (text)
      - joined_at (timestamp)
    
    - activity_logs
      - id (uuid, primary key)
      - team_id (uuid, references teams)
      - user_id (uuid, references users)
      - action (text)
      - ip_address (text)
      - timestamp (timestamp)
    
    - invitations
      - id (uuid, primary key)
      - team_id (uuid, references teams)
      - email (text)
      - role (text)
      - invited_by (uuid, references users)
      - status (text)
      - invited_at (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  email text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  name text,
  role text DEFAULT 'member' NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone
);

-- Teams table
CREATE TABLE IF NOT EXISTS teams (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  stripe_customer_id text UNIQUE,
  stripe_subscription_id text UNIQUE,
  stripe_product_id text,
  plan_name text,
  subscription_status text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Team members table
CREATE TABLE IF NOT EXISTS team_members (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id uuid REFERENCES teams(id) NOT NULL,
  user_id uuid REFERENCES users(id) NOT NULL,
  role text NOT NULL,
  joined_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Activity logs table
CREATE TABLE IF NOT EXISTS activity_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id uuid REFERENCES teams(id) NOT NULL,
  user_id uuid REFERENCES users(id),
  action text NOT NULL,
  ip_address text,
  timestamp timestamp with time zone DEFAULT now() NOT NULL
);

-- Invitations table
CREATE TABLE IF NOT EXISTS invitations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id uuid REFERENCES teams(id) NOT NULL,
  email text NOT NULL,
  role text NOT NULL,
  invited_by uuid REFERENCES users(id) NOT NULL,
  status text DEFAULT 'pending' NOT NULL,
  invited_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can read own data" ON users
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Team members can read their team" ON teams
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = teams.id
      AND team_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Team members can read team members" ON team_members
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM team_members tm
      WHERE tm.team_id = team_members.team_id
      AND tm.user_id = auth.uid()
    )
  );

CREATE POLICY "Team members can read activity logs" ON activity_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = activity_logs.team_id
      AND team_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Team members can read invitations" ON invitations
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = invitations.team_id
      AND team_members.user_id = auth.uid()
    )
  );