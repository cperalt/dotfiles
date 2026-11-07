import { OPERATOR_MOTIONS, OPERATORS, parseCount, SIMPLE_MOTIONS, type CommandState, type Mode, type MotionKey, type Operator } from "./types";

export type TransitionContext = {
  moveMotion: (motion: MotionKey, count: number) => void;
  executeOperatorMotion: (op: Operator, motion: MotionKey, count: number) => void;
  executeLineOp: (op: Operator, count: number) => void;
  executeDeleteChar: (count: number) => void;
  executePaste: (after: boolean, count: number) => void;
  goToFirstLine: (count: number) => void;
  goToLastLine: (count: number) => void;
  goToLineStart: () => void;
  enterInsert: (kind: "i" | "a" | "I" | "A" | "o" | "O") => void;
  undo: () => void;
};

export type TransitionResult = {
  next: CommandState;
  mode?: Mode;
  handled: boolean;
};

function idle(): TransitionResult {
  return { next: { type: "idle" }, handled: true };
}

function handleNormalInput(input: string, count: number, ctx: TransitionContext): TransitionResult | null {
  if (input in OPERATORS) {
    return { next: { type: "operator", op: OPERATORS[input as keyof typeof OPERATORS], count }, handled: true };
  }

  if (SIMPLE_MOTIONS.has(input as MotionKey)) {
    ctx.moveMotion(input as MotionKey, count);
    return idle();
  }

  if (input === "g") return { next: { type: "g", count }, handled: true };
  if (input === "G") {
    ctx.goToLastLine(count);
    return idle();
  }
  if (input === "x") {
    ctx.executeDeleteChar(count);
    return idle();
  }
  if (input === "u") {
    ctx.undo();
    return idle();
  }
  if (input === "p") {
    ctx.executePaste(true, count);
    return idle();
  }
  if (input === "P") {
    ctx.executePaste(false, count);
    return idle();
  }
  if (input === "i" || input === "a" || input === "I" || input === "A" || input === "o" || input === "O") {
    ctx.enterInsert(input);
    return { next: { type: "idle" }, mode: "insert", handled: true };
  }

  return null;
}

function handleOperatorInput(state: Extract<CommandState, { type: "operator" | "operatorCount" }>, input: string, ctx: TransitionContext): TransitionResult | null {
  const count = state.type === "operatorCount" ? state.count * parseCount(state.digits) : state.count;

  if (input in OPERATORS) {
    if (OPERATORS[input as keyof typeof OPERATORS] === state.op) {
      ctx.executeLineOp(state.op, count);
      return idle();
    }
    return idle();
  }

  if (OPERATOR_MOTIONS.has(input as MotionKey)) {
    ctx.executeOperatorMotion(state.op, input as MotionKey, count);
    return idle();
  }

  return idle();
}

export function transition(state: CommandState, input: string, ctx: TransitionContext): TransitionResult {
  switch (state.type) {
    case "idle": {
      if (/[1-9]/.test(input)) return { next: { type: "count", digits: input }, handled: true };
      if (input === "0") {
        ctx.goToLineStart();
        return idle();
      }
      return handleNormalInput(input, 1, ctx) ?? { next: state, handled: false };
    }

    case "count": {
      if (/\d/.test(input)) {
        return { next: { type: "count", digits: `${state.digits}${input}` }, handled: true };
      }
      return handleNormalInput(input, parseCount(state.digits), ctx) ?? idle();
    }

    case "operator": {
      if (/\d/.test(input)) {
        return { next: { type: "operatorCount", op: state.op, count: state.count, digits: input }, handled: true };
      }
      return handleOperatorInput(state, input, ctx) ?? idle();
    }

    case "operatorCount": {
      if (/\d/.test(input)) {
        return { next: { type: "operatorCount", op: state.op, count: state.count, digits: `${state.digits}${input}` }, handled: true };
      }
      return handleOperatorInput(state, input, ctx) ?? idle();
    }

    case "g": {
      if (input === "g") {
        ctx.goToFirstLine(state.count);
        return idle();
      }
      return idle();
    }
  }
}
