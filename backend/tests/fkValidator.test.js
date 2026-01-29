/**
 * Testes para o FK Validator
 *
 * Valida que as FKs são corretamente validadas para evitar
 * referências cruzadas entre usuários.
 */

const { sequelize } = require('../src/config/database');

// Mock do sequelize.query
jest.mock('../src/config/database', () => ({
  sequelize: {
    query: jest.fn(),
    QueryTypes: { SELECT: 'SELECT' }
  }
}));

// Mock do logger
jest.mock('../src/utils/logger', () => ({
  warn: jest.fn(),
  info: jest.fn(),
  error: jest.fn(),
  debug: jest.fn()
}));

const {
  validateFKs,
  validateAccountTypeOwnership,
  validateAccountDescriptionOwnership,
  validateAccountDescriptionFKs,
  validateAccountFKs
} = require('../src/utils/fkValidator');

describe('FK Validator', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('validateAccountTypeOwnership', () => {
    it('deve retornar valid=true para FK nula', async () => {
      const result = await validateAccountTypeOwnership(null, 1);
      expect(result.valid).toBe(true);
    });

    it('deve retornar valid=true quando account_type pertence ao usuário', async () => {
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 1 }]);

      const result = await validateAccountTypeOwnership(100, 1);
      expect(result.valid).toBe(true);
    });

    it('deve retornar valid=false quando account_type não existe', async () => {
      sequelize.query.mockResolvedValueOnce([undefined]);

      const result = await validateAccountTypeOwnership(999, 1);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('não encontrado');
    });

    it('deve retornar valid=false quando account_type pertence a outro usuário', async () => {
      // account_type 100 pertence ao user_id 2, mas estamos validando para user_id 1
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 2 }]);

      const result = await validateAccountTypeOwnership(100, 1);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('não pertence ao usuário');
    });
  });

  describe('validateAccountDescriptionOwnership', () => {
    it('deve retornar valid=true para FK nula', async () => {
      const result = await validateAccountDescriptionOwnership(null, 1);
      expect(result.valid).toBe(true);
    });

    it('deve retornar valid=true quando account_description pertence ao usuário', async () => {
      sequelize.query.mockResolvedValueOnce([{ id: 50, user_id: 1 }]);

      const result = await validateAccountDescriptionOwnership(50, 1);
      expect(result.valid).toBe(true);
    });

    it('deve retornar valid=false quando account_description pertence a outro usuário', async () => {
      sequelize.query.mockResolvedValueOnce([{ id: 50, user_id: 2 }]);

      const result = await validateAccountDescriptionOwnership(50, 1);
      expect(result.valid).toBe(false);
      expect(result.error).toContain('não pertence ao usuário');
    });
  });

  describe('validateAccountDescriptionFKs', () => {
    it('deve validar accountId corretamente', async () => {
      // accountId 100 pertence ao user_id 1
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 1 }]);

      const data = { accountId: 100, description: 'Test' };
      const result = await validateAccountDescriptionFKs(data, 1);

      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('deve rejeitar accountId de outro usuário', async () => {
      // accountId 100 pertence ao user_id 2
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 2 }]);

      const data = { accountId: 100, description: 'Test' };
      const result = await validateAccountDescriptionFKs(data, 1);

      expect(result.valid).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toContain('não pertence ao usuário');
    });
  });

  describe('validateAccountFKs', () => {
    it('deve validar typeId e categoryId corretamente', async () => {
      // typeId 100 pertence ao user_id 1
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 1 }]);
      // categoryId 50 pertence ao user_id 1
      sequelize.query.mockResolvedValueOnce([{ id: 50, user_id: 1 }]);

      const data = { typeId: 100, categoryId: 50, description: 'Test' };
      const result = await validateAccountFKs(data, 1);

      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('deve rejeitar typeId de outro usuário', async () => {
      // typeId 100 pertence ao user_id 2 (outro usuário!)
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 2 }]);

      const data = { typeId: 100, description: 'Test' };
      const result = await validateAccountFKs(data, 1);

      expect(result.valid).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toContain('account_type');
    });

    it('deve rejeitar categoryId de outro usuário', async () => {
      // typeId 100 pertence ao user_id 1
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 1 }]);
      // categoryId 50 pertence ao user_id 2 (outro usuário!)
      sequelize.query.mockResolvedValueOnce([{ id: 50, user_id: 2 }]);

      const data = { typeId: 100, categoryId: 50, description: 'Test' };
      const result = await validateAccountFKs(data, 1);

      expect(result.valid).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toContain('account_description');
    });

    it('deve validar cardId corretamente', async () => {
      // Sem typeId/categoryId
      // cardId 200 pertence ao user_id 1
      sequelize.query.mockResolvedValueOnce([{ id: 200, user_id: 1 }]);

      const data = { cardId: 200, description: 'Despesa do cartão' };
      const result = await validateAccountFKs(data, 1);

      expect(result.valid).toBe(true);
    });

    it('deve rejeitar cardId de outro usuário', async () => {
      // cardId 200 pertence ao user_id 2
      sequelize.query.mockResolvedValueOnce([{ id: 200, user_id: 2 }]);

      const data = { cardId: 200, description: 'Despesa do cartão' };
      const result = await validateAccountFKs(data, 1);

      expect(result.valid).toBe(false);
      expect(result.errors[0]).toContain('card_id');
    });

    it('deve validar recurrenceId corretamente', async () => {
      // recurrenceId 300 pertence ao user_id 1
      sequelize.query.mockResolvedValueOnce([{ id: 300, user_id: 1 }]);

      const data = { recurrenceId: 300, description: 'Conta recorrente' };
      const result = await validateAccountFKs(data, 1);

      expect(result.valid).toBe(true);
    });

    it('deve rejeitar recurrenceId de outro usuário', async () => {
      // recurrenceId 300 pertence ao user_id 2
      sequelize.query.mockResolvedValueOnce([{ id: 300, user_id: 2 }]);

      const data = { recurrenceId: 300, description: 'Conta recorrente' };
      const result = await validateAccountFKs(data, 1);

      expect(result.valid).toBe(false);
      expect(result.errors[0]).toContain('recurrence_id');
    });

    it('deve acumular múltiplos erros de FK', async () => {
      // typeId pertence a outro usuário
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 2 }]);
      // categoryId pertence a outro usuário
      sequelize.query.mockResolvedValueOnce([{ id: 50, user_id: 2 }]);

      const data = { typeId: 100, categoryId: 50, description: 'Test' };
      const result = await validateAccountFKs(data, 1);

      expect(result.valid).toBe(false);
      expect(result.errors).toHaveLength(2);
    });
  });

  describe('validateFKs (dispatcher)', () => {
    it('deve chamar validador correto para account_descriptions', async () => {
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 1 }]);

      const data = { accountId: 100, description: 'Test' };
      const result = await validateFKs('account_descriptions', data, 1);

      expect(result.valid).toBe(true);
    });

    it('deve chamar validador correto para accounts', async () => {
      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 1 }]);

      const data = { typeId: 100, description: 'Test' };
      const result = await validateFKs('accounts', data, 1);

      expect(result.valid).toBe(true);
    });

    it('deve retornar valid=true para tabelas sem validador', async () => {
      const result = await validateFKs('account_types', { name: 'Test' }, 1);

      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('deve retornar valid=true para banks (sem FKs de usuário)', async () => {
      const result = await validateFKs('banks', { name: 'Banco Test' }, 1);

      expect(result.valid).toBe(true);
    });
  });

  describe('Cenários de ataque prevenidos', () => {
    it('deve prevenir usuário A acessando account_type de usuário B', async () => {
      // Cenário: Usuário A (id=1) tenta criar account_description
      // referenciando account_type (id=100) que pertence ao Usuário B (id=2)

      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 2 }]); // Pertence ao user 2!

      const maliciousData = {
        accountId: 100, // FK para account_type do outro usuário
        description: 'Tentativa de acesso cruzado'
      };

      const result = await validateFKs('account_descriptions', maliciousData, 1);

      expect(result.valid).toBe(false);
      expect(result.errors[0]).toContain('não pertence ao usuário');
    });

    it('deve prevenir usuário A criando account com typeId de usuário B', async () => {
      // Cenário: Usuário A tenta criar uma conta usando o tipo do Usuário B

      sequelize.query.mockResolvedValueOnce([{ id: 100, user_id: 2 }]); // Pertence ao user 2!

      const maliciousData = {
        typeId: 100, // FK para account_type do outro usuário
        categoryId: null,
        description: 'Conta maliciosa',
        value: 1000
      };

      const result = await validateFKs('accounts', maliciousData, 1);

      expect(result.valid).toBe(false);
      expect(result.errors).toHaveLength(1);
    });

    it('deve prevenir referência a cartão de crédito de outro usuário', async () => {
      // Cenário: Usuário A tenta criar despesa vinculada ao cartão do Usuário B

      sequelize.query.mockResolvedValueOnce([{ id: 500, user_id: 2 }]); // Cartão do user 2!

      const maliciousData = {
        cardId: 500, // FK para cartão do outro usuário
        description: 'Despesa vinculada ao cartão errado',
        value: 500
      };

      const result = await validateFKs('accounts', maliciousData, 1);

      expect(result.valid).toBe(false);
      expect(result.errors[0]).toContain('card_id');
    });
  });
});
