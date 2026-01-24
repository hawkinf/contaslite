/**
 * Modelo EmailSchedule - Configuração de agendamento de emails por usuário
 */
const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const EmailSchedule = sequelize.define('EmailSchedule', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    unique: true,
    references: {
      model: 'users',
      key: 'id'
    }
  },
  is_enabled: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  frequency: {
    type: DataTypes.ENUM('daily', 'weekly', 'biweekly', 'monthly'),
    defaultValue: 'daily'
  },
  send_hour: {
    type: DataTypes.INTEGER,
    defaultValue: 3,
    validate: {
      min: 0,
      max: 23
    }
  },
  send_minute: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    validate: {
      min: 0,
      max: 59
    }
  },
  weekly_day: {
    type: DataTypes.INTEGER,
    defaultValue: 1,
    validate: {
      min: 0,
      max: 6
    }
  },
  monthly_day: {
    type: DataTypes.INTEGER,
    defaultValue: 1,
    validate: {
      min: 1,
      max: 28
    }
  },
  last_sent_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  next_send_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  }
}, {
  tableName: 'email_schedules',
  timestamps: false,
  underscored: true
});

module.exports = EmailSchedule;
