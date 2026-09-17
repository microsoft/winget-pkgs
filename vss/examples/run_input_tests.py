import subprocess
import os
import tempfile
import sys

VSS_EXE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "vss.exe"))

def run_test_case(name, vss_code, input_str, expected_stdout=None, expected_stderr=None, expected_exit_code=0, compile_first=False):
    print(f"Running test: {name} ...", end="", flush=True)
    
    # Create temp vss file
    temp_fd, temp_path = tempfile.mkstemp(suffix=".vss")
    try:
        with os.fdopen(temp_fd, 'w') as tmp:
            tmp.write(vss_code)
            
        executable_path = temp_path
        
        if compile_first:
            # Build vss code
            build_res = subprocess.run([VSS_EXE, "build", temp_path], capture_output=True, text=True)
            if build_res.returncode != 0:
                print(f" BUILD FAILED: {build_res.stderr}")
                return False
            # Compiled path is temp_path + "c"
            compiled_path = temp_path + "c"
            if not os.path.exists(compiled_path):
                print(f" BUILD FAILED: Compiled file {compiled_path} not found")
                return False
            executable_path = compiled_path

        # Run executable
        res = subprocess.run([VSS_EXE, executable_path], input=input_str, capture_output=True, text=True)
        
        # Cleanup compiled file
        if compile_first and os.path.exists(compiled_path):
            os.remove(compiled_path)

        # Check exit code
        if res.returncode != expected_exit_code:
            print(f" FAILED (exit code {res.returncode}, expected {expected_exit_code})")
            print(f"STDOUT:\n{res.stdout}\nSTDERR:\n{res.stderr}")
            return False
            
        # Check stdout
        if expected_stdout and expected_stdout not in res.stdout:
            print(" FAILED (stdout mismatch)")
            print(f"EXPECTED STDOUT TO CONTAIN: {expected_stdout}")
            print(f"ACTUAL STDOUT:\n{res.stdout}")
            return False
            
        # Check stderr
        if expected_stderr and expected_stderr not in res.stderr:
            print(" FAILED (stderr mismatch)")
            print(f"EXPECTED STDERR TO CONTAIN: {expected_stderr}")
            print(f"ACTUAL STDERR:\n{res.stderr}")
            return False
            
        print(" PASSED")
        return True
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

tests = [
    # 1. String input
    {
        "name": "String Input",
        "vss_code": 'make name becomes ""\nask name\nsay "Name: " + name\n',
        "input_str": "Alice\n",
        "expected_stdout": "Name: Alice"
    },
    # 2. Integer input
    {
        "name": "Integer Input",
        "vss_code": 'make age becomes 0\nask age\nsay "Next: " + (age + 1)\n',
        "input_str": "25\n",
        "expected_stdout": "Next: 26"
    },
    # 3. Float input
    {
        "name": "Float Input",
        "vss_code": 'make val becomes 0.0\nask val\nsay "Next: " + (val + 1.5)\n',
        "input_str": "3.14\n",
        "expected_stdout": "Next: 4.64"
    },
    # 4. Boolean input
    {
        "name": "Boolean Input",
        "vss_code": 'make flag becomes yes\nask flag\nwhen flag same_as yes\nsay "YES"\notherwise\nsay "NO"\nfinish\n',
        "input_str": "no\n",
        "expected_stdout": "NO"
    },
    # 5. Prompt handling
    {
        "name": "Prompt Handling",
        "vss_code": 'make name becomes ""\nask "Enter Name: " into name\nsay name\n',
        "input_str": "Bob\n",
        "expected_stdout": "Enter Name: Bob"
    },
    # 6. Empty numeric input
    {
        "name": "Empty Numeric Input",
        "vss_code": 'make age becomes 0\nask age\n',
        "input_str": "\n",
        "expected_stderr": "Input Error: Expected a number but received empty input.",
        "expected_exit_code": 1
    },
    # 7. Invalid number
    {
        "name": "Invalid Number",
        "vss_code": 'make age becomes 0\nask age\n',
        "input_str": "hello\n",
        "expected_stderr": 'Input Error: Expected a number but received "hello".',
        "expected_exit_code": 1
    },
    # 8. Invalid boolean
    {
        "name": "Invalid Boolean",
        "vss_code": 'make flag becomes yes\nask flag\n',
        "input_str": "maybe\n",
        "expected_stderr": 'Input Error: Expected a boolean but received "maybe".',
        "expected_exit_code": 1
    },
    # 9. EOF / Stdin failure
    {
        "name": "EOF Handling",
        "vss_code": 'make name becomes ""\nask name\n',
        "input_str": "", # Send EOF immediately
        "expected_stderr": "Input Error: End of file or stdin failure.",
        "expected_exit_code": 1
    },
    # 10. Immutable variable
    {
        "name": "Immutable Variable (semantic check)",
        "vss_code": 'keep name becomes "constant"\nask name\n',
        "input_str": "newval\n",
        "expected_stderr": "Cannot assign input to constant 'name'.",
        "expected_exit_code": 1
    },
    # 11. Undefined variable
    {
        "name": "Undefined Variable (semantic check)",
        "vss_code": 'ask name\n',
        "input_str": "val\n",
        "expected_stderr": "Variable 'name' is not defined.",
        "expected_exit_code": 1
    },
    # 12. Multiple input statements
    {
        "name": "Multiple Inputs",
        "vss_code": 'make a becomes ""\nmake b becomes ""\nask a\nask b\nsay a + " and " + b\n',
        "input_str": "First\nSecond\n",
        "expected_stdout": "First and Second"
    },
    # 13. Input followed by conditions
    {
        "name": "Input with Conditions",
        "vss_code": 'make age becomes 0\nask age\nwhen age above 18\nsay "adult"\notherwise\nsay "minor"\nfinish\n',
        "input_str": "20\n",
        "expected_stdout": "adult"
    },
    # 14. Input inside loops
    {
        "name": "Input inside Loops",
        "vss_code": 'make total becomes 0\nrepeat 3 times\nmake x becomes 0\nask x\ntotal becomes total + x\nfinish\nsay total\n',
        "input_str": "10\n20\n30\n",
        "expected_stdout": "60"
    },
    # 15. Input inside functions
    {
        "name": "Input inside Functions",
        "vss_code": 'task get_inp\nmake x becomes ""\nask x\nsend x\nfinish\nsay get_inp()\n',
        "input_str": "function_input\n",
        "expected_stdout": "function_input"
    },
    # 16. Input in compiled execution
    {
        "name": "Compiled Execution (build)",
        "vss_code": 'make name becomes ""\nask "Who: " into name\nsay "Hello " + name\n',
        "input_str": "Developer\n",
        "expected_stdout": "Who: Hello Developer",
        "compile_first": True
    }
]

success = True
for test in tests:
    ok = run_test_case(
        test["name"],
        test["vss_code"],
        test["input_str"],
        expected_stdout=test.get("expected_stdout"),
        expected_stderr=test.get("expected_stderr"),
        expected_exit_code=test.get("expected_exit_code", 0),
        compile_first=test.get("compile_first", False)
    )
    if not ok:
        success = False

if success:
    print("\nALL INPUT TESTS PASSED SUCCESSFULLY!")
    sys.exit(0)
else:
    print("\nSOME TESTS FAILED!")
    sys.exit(1)
