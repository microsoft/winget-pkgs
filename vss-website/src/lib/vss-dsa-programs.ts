export interface DsaTopic {
  id: string;
  slug: string;
  title: string;
  category: 'Arrays' | 'Strings' | 'Stacks & Queues' | 'Sorting & Searching' | 'Recursion' | 'Hash Maps & Sets' | 'Dynamic Programming';
  difficulty: 'Easy' | 'Medium' | 'Hard';
  concept: string;
  algorithm: string;
  vssCode: string;
  vssOutput: string;
  lineByLine: { line: string; desc: string }[];
  timeComplexity: string;
  spaceComplexity: string;
  dryRun: string;
  practiceProblem: { title: string; prompt: string; hint: string; solution: string };
}

export interface ProgramItem {
  id: string;
  slug: string;
  title: string;
  category: 'Basic' | 'Numbers' | 'Strings' | 'Arrays' | 'Files' | 'Database' | 'HTTP & Web' | 'Concurrency';
  difficulty: 'Basic' | 'Intermediate' | 'Advanced';
  problem: string;
  approach: string;
  vssCode: string;
  vssOutput: string;
  explanation: { line: string; desc: string }[];
}

export const DSA_TOPICS: DsaTopic[] = [
  {
    id: "dsa-linear-search",
    slug: "linear-search",
    title: "Linear Search Algorithm",
    category: "Sorting & Searching",
    difficulty: "Easy",
    concept: "Linear Search sequentially checks each element in a list until the target value is found or the end of the list is reached.",
    algorithm: "1. Iterate through list indices from 0 to N-1.\n2. Compare list[i] with target.\n3. If equal, return index i.\n4. If loop finishes without match, return -1.",
    vssCode: `task linear_search needs list_arr, target
  make len becomes list_arr.length
  repeat i through 0 to len - 1
    when list_arr[i] == target
      send i
    finish
  finish
  send -1
finish

make numbers becomes [10, 25, 30, 45, 90]
make idx becomes linear_search(numbers, 30)
say "Found target 30 at index: " + idx`,
    vssOutput: `Found target 30 at index: 2`,
    lineByLine: [
      { line: "task linear_search needs list_arr, target", desc: "Defines function linear_search receiving array and target value." },
      { line: "repeat i through 0 to len - 1", desc: "Iterates through array indices." },
      { line: "when list_arr[i] == target", desc: "Compares current element with target value." },
      { line: "send i", desc: "Returns index immediately upon finding match." }
    ],
    timeComplexity: "O(N) - Linear Time",
    spaceComplexity: "O(1) - Constant Auxiliary Space",
    dryRun: "Input: [10, 25, 30, 45, 90], Target: 30\nStep 1: i=0, val=10 != 30\nStep 2: i=1, val=25 != 30\nStep 3: i=2, val=30 == 30 -> Return 2.",
    practiceProblem: {
      title: "Find First Negative Number",
      prompt: "Write a VSS task `find_first_negative` that returns the index of the first negative number in a list.",
      hint: "Use linear search and check `element < 0`.",
      solution: `task find_first_negative needs items
  make n becomes items.length
  repeat i through 0 to n - 1
    when items[i] < 0
      send i
    finish
  finish
  send -1
finish`
    }
  },
  {
    id: "dsa-bubble-sort",
    slug: "bubble-sort",
    title: "Bubble Sort Algorithm",
    category: "Sorting & Searching",
    difficulty: "Easy",
    concept: "Bubble Sort repeatedly steps through the array, compares adjacent elements, and swaps them if they are in the wrong order.",
    algorithm: "1. Outer loop runs N times.\n2. Inner loop compares adjacent pairs (j, j+1).\n3. Swap if arr[j] > arr[j+1].\n4. Array is sorted after N passes.",
    vssCode: `task bubble_sort needs arr
  make n becomes arr.length
  repeat i through 0 to n - 1
    repeat j through 0 to n - i - 2
      when arr[j] > arr[j + 1]
        make temp becomes arr[j]
        arr[j] becomes arr[j + 1]
        arr[j + 1] becomes temp
      finish
    finish
  finish
  send arr
finish

make nums becomes [64, 34, 25, 12, 22]
make sorted_nums becomes bubble_sort(nums)
say "Sorted Array: " + sorted_nums`,
    vssOutput: `Sorted Array: [12, 22, 25, 34, 64]`,
    lineByLine: [
      { line: "repeat i through 0 to n - 1", desc: "Outer pass counter." },
      { line: "repeat j through 0 to n - i - 2", desc: "Inner pass comparing adjacent items." },
      { line: "when arr[j] > arr[j + 1]", desc: "Checks if adjacent pair is out of order." },
      { line: "make temp becomes arr[j]", desc: "Swaps adjacent values using temporary variable." }
    ],
    timeComplexity: "O(N^2) - Quadratic Time",
    spaceComplexity: "O(1) - In-place Sorting Space",
    dryRun: "Pass 1: Largest element 64 bubbles to end.\nPass 2: 34 bubbles to second-to-last position.\nFinal sorted list: [12, 22, 25, 34, 64]",
    practiceProblem: {
      title: "Sort String Characters",
      prompt: "Sort a list of strings alphabetically using bubble sort in VSS.",
      hint: "Compare string values using standard comparison operators.",
      solution: `task sort_strings needs list_str
  make n becomes list_str.length
  repeat i through 0 to n - 1
    repeat j through 0 to n - i - 2
      when list_str[j] > list_str[j + 1]
        make temp becomes list_str[j]
        list_str[j] becomes list_str[j + 1]
        list_str[j + 1] becomes temp
      finish
    finish
  finish
  send list_str
finish`
    }
  }
];

export const VSS_PROGRAMS: ProgramItem[] = [
  {
    id: "prog-even-odd",
    slug: "even-odd-checker",
    title: "Check Even or Odd Number",
    category: "Numbers",
    difficulty: "Basic",
    problem: "Determine if an integer is even or odd.",
    approach: "Use modulo operator `% 2`. If remainder is 0, the number is even.",
    vssCode: `make num becomes 24

when num % 2 == 0
  say num + " is Even"
otherwise
  say num + " is Odd"
finish`,
    vssOutput: `24 is Even`,
    explanation: [
      { line: "make num becomes 24", desc: "Stores integer 24 in variable `num`." },
      { line: "when num % 2 == 0", desc: "Checks if remainder when divided by 2 equals 0." },
      { line: "say num + \" is Even\"", desc: "Prints result text." }
    ]
  },
  {
    id: "prog-factorial",
    slug: "factorial-calculator",
    title: "Calculate Factorial of N",
    category: "Numbers",
    difficulty: "Basic",
    problem: "Calculate n! = n * (n-1) * ... * 1.",
    approach: "Iterate from 1 to N and multiply accumulative result.",
    vssCode: `task factorial needs n
  make result becomes 1
  repeat i through 1 to n
    result becomes result * i
  finish
  send result
finish

say "Factorial of 5 = " + factorial(5)`,
    vssOutput: `Factorial of 5 = 120`,
    explanation: [
      { line: "task factorial needs n", desc: "Function calculating factorial." },
      { line: "make result becomes 1", desc: "Initializes multiplier result." },
      { line: "repeat i through 1 to n", desc: "Loops from 1 up to N." }
    ]
  }
];
