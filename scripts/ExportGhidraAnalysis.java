// Export bounded, line-oriented Ghidra evidence only inside the static-analysis boundary.
import java.io.File;
import java.io.PrintWriter;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.block.BasicBlockModel;
import ghidra.program.model.block.CodeBlock;
import ghidra.program.model.block.CodeBlockIterator;
import ghidra.program.model.block.CodeBlockReference;
import ghidra.program.model.block.CodeBlockReferenceIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.symbol.Reference;

public class ExportGhidraAnalysis extends GhidraScript {
    private int emitted;
    private int maxRecords;
    private int maxString;

    private String json(String value) {
        if (value == null) return "null";
        if (value.length() > maxString) value = value.substring(0, maxString);
        StringBuilder result = new StringBuilder("\"");
        for (int index = 0; index < value.length(); index++) {
            char character = value.charAt(index);
            switch (character) {
                case '\\': result.append("\\\\"); break;
                case '"': result.append("\\\""); break;
                case '\n': result.append("\\n"); break;
                case '\r': result.append("\\r"); break;
                case '\t': result.append("\\t"); break;
                default:
                    if (character < 0x20) result.append(String.format("\\u%04x", (int) character));
                    else result.append(character);
            }
        }
        return result.append('"').toString();
    }

    private String address(Address value) {
        return value == null ? "null" : json(Long.toUnsignedString(value.getOffset()));
    }

    private static String operands(Instruction instruction) {
        StringBuilder result = new StringBuilder();
        for (int index = 0; index < instruction.getNumOperands(); index++) {
            if (index > 0) result.append(", ");
            result.append(instruction.getDefaultOperandRepresentation(index));
        }
        return result.toString();
    }

    private boolean emit(PrintWriter output, String record) {
        if (emitted >= maxRecords) return false;
        output.println(record);
        emitted++;
        return true;
    }

    @Override
    public void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length != 3) {
            throw new IllegalArgumentException("Expected output path, max records, and max string length.");
        }
        maxRecords = Integer.parseInt(arguments[1]);
        maxString = Integer.parseInt(arguments[2]);
        if (maxRecords < 1 || maxString < 1) throw new IllegalArgumentException("Bounds must be positive.");

        Listing listing = currentProgram.getListing();
        BasicBlockModel blockModel = new BasicBlockModel(currentProgram);
        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        try (PrintWriter output = new PrintWriter(new File(arguments[0]), "UTF-8")) {
            FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
            while (functions.hasNext() && !monitor.isCancelled() && emitted < maxRecords) {
                Function function = functions.next();
                String entry = Long.toUnsignedString(function.getEntryPoint().getOffset());
                DecompileResults decompiled = decompiler.decompileFunction(function, 30, monitor);
                String state = decompiled.decompileCompleted() ? "complete" : "failed";
                String code = decompiled.decompileCompleted() ? decompiled.getDecompiledFunction().getC() : null;
                String error = decompiled.decompileCompleted() ? null : decompiled.getErrorMessage();
                emit(output, "{\"Kind\":\"Function\",\"Address\":" + json(entry)
                    + ",\"Name\":" + json(function.getName(true))
                    + ",\"Namespace\":" + json(function.getParentNamespace().getName(true))
                    + ",\"Signature\":" + json(function.getSignature().getPrototypeString())
                    + ",\"Size\":" + function.getBody().getNumAddresses()
                    + ",\"DecompileState\":" + json(state)
                    + ",\"DecompiledCode\":" + json(code)
                    + ",\"DecompileError\":" + json(error) + "}");

                InstructionIterator instructions = listing.getInstructions(function.getBody(), true);
                while (instructions.hasNext() && !monitor.isCancelled() && emitted < maxRecords) {
                    Instruction instruction = instructions.next();
                    emit(output, "{\"Kind\":\"Instruction\",\"FunctionAddress\":" + json(entry)
                        + ",\"Address\":" + address(instruction.getAddress())
                        + ",\"Mnemonic\":" + json(instruction.getMnemonicString())
                        + ",\"Operands\":" + json(operands(instruction)) + "}");
                    for (Reference reference : instruction.getReferencesFrom()) {
                        if (emitted >= maxRecords) break;
                        if (reference.getReferenceType().isCall()) {
                            Function callee = currentProgram.getFunctionManager().getFunctionAt(reference.getToAddress());
                            emit(output, "{\"Kind\":\"CallReference\",\"CallerAddress\":" + json(entry)
                                + ",\"CallsiteAddress\":" + address(instruction.getAddress())
                                + ",\"CalleeAddress\":" + address(reference.getToAddress())
                                + ",\"CalleeName\":" + json(callee == null ? null : callee.getName(true)) + "}");
                        }
                    }
                }

                CodeBlockIterator blocks = blockModel.getCodeBlocksContaining(function.getBody(), monitor);
                while (blocks.hasNext() && !monitor.isCancelled() && emitted < maxRecords) {
                    CodeBlock block = blocks.next();
                    Address blockAddress = block.getFirstStartAddress();
                    emit(output, "{\"Kind\":\"BasicBlock\",\"FunctionAddress\":" + json(entry)
                        + ",\"Address\":" + address(blockAddress)
                        + ",\"EndAddress\":" + address(block.getMaxAddress()) + "}");
                    CodeBlockReferenceIterator edges = block.getDestinations(monitor);
                    while (edges.hasNext() && emitted < maxRecords) {
                        CodeBlockReference edge = edges.next();
                        emit(output, "{\"Kind\":\"BlockReference\",\"FunctionAddress\":" + json(entry)
                            + ",\"SourceAddress\":" + address(blockAddress)
                            + ",\"TargetAddress\":" + address(edge.getDestinationAddress())
                            + ",\"EdgeType\":" + json(edge.getFlowType().getName()) + "}");
                    }
                }
            }
        } finally {
            decompiler.dispose();
        }
    }
}
