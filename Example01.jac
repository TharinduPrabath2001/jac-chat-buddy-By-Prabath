import:py from jaclang.core.llms, Anthropic;

glob llm = Anthropic(model_name="claude-3-sonnet-20240229");

obj Employer {
    has employer_name:str;
    has location:str;
}

obj Person {
    has name:str;
    has age:int;
    has employer:Employer;
    has job:str;
}

with entry {
    info:'Information about a person':str = "Sarah is 25 years old and works at Google as a software engineer."
                                            "She lives in san-francisco.";
    person = Person(by llm(incl_info=(info)));
    print(person);
}
