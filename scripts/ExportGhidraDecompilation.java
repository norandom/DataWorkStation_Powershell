// Best-effort headless Ghidra exporter. It runs only inside an isolated analysis boundary.
import java.io.File;
import java.io.PrintWriter;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;

public class ExportGhidraDecompilation extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length != 1) {
            throw new IllegalArgumentException("Expected one output path.");
        }
        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        try (PrintWriter output = new PrintWriter(new File(arguments[0]), "UTF-8")) {
            FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
            while (functions.hasNext() && !monitor.isCancelled()) {
                Function function = functions.next();
                DecompileResults result = decompiler.decompileFunction(function, 30, monitor);
                output.println("/* " + function.getName() + " @ " + function.getEntryPoint() + " */");
                if (result.decompileCompleted()) {
                    output.println(result.getDecompiledFunction().getC());
                } else {
                    output.println("/* decompilation failed: " + result.getErrorMessage() + " */");
                }
            }
        } finally {
            decompiler.dispose();
        }
    }
}
