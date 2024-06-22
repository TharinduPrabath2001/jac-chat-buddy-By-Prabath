import:py random;
import:py from jaclang.core.llms, Anthropic;
import:py streamlit as st;

glob llm = Anthropic(model_name="claude-3-sonnet-20240229");

enum PR_states {
    init_PR = 'initial run',
    session_create = 'create session graph',
    chat_create = 'create chat graph',
    chat = 'chat with user'
}

glob state = PR_states.init_PR;

enum task_type {
    # RAG_type : 'Need to use Retrivable information in specific finacial articles' = "RAG",
    QA_TYPE : 'Need to use given user information' = "user_qa",
    TODO_TYPE : 'Need to use the todo list of the user' = "todo"
}

'''
User node has user_name attribute.
'''
node user{
    has user_name:string="user";
}

'''
Chat session of a user. This node contains the session_id, user_data and todo_list.
This should also include the chat history. Can have multiple chat sessions.
'''
node session{
    has session_id : string = 100;
    has user_data : dict = {}; # User data such as habits, heart rate etc.
    has todo_list : list = []; # List of things to do by the user.
    has session_chat_history : list = [];
}

'''
Consists of user data such as age, pressure, married status.
'''
node data{
    has user_data:dict = {
        "age" : 0,
        "Pressure" : (0,0),
        "Married" : False
    };
}

'''
List of things to do by the user.
'''
node todo{
    has todo_list:list = [];
}

'''
This is the chat walker which will be used to chat with the user.
The create_session ability:
    - gather the user data and todo list from connected nodes using filters.
    - Creates a new session with the user data and todo list.
    - Spawns the chat session with the session id.
'''
walker chat{
    can create_session with user entry{
        # Telescope into the nodes connected to the user node without walking.
        data_node = [-->](`?data)[0]; # Getting the data node filtered. can use [0] as having only one such node.
        todo_node = [-->](`?todo)[0]; # Getting the todo node filtered. can use [0] as having only one such node.
        new_session_id = str(random.randint(1,100));
        # Creating a new session node with the user data and todo list and connect it to the user.
        n = here ++> session(   
            session_id = new_session_id,
            user_data = data_node.user_data,
            todo_list = todo_node.todo_list,
            session_chat_history = []
            );
        visit n;
    }
    can chat_session with session entry{
        # for i=0 to i<2 by i+=1 {
        here.session_chat_history.clear();
        query() spawn here;
        # }
    }
}

'''
This is the query walker which will be used to query a user input and generate a response.
The init_query_engine ability:
    - Gathers the user data and todo list from the user node.
    - Asks the user for the routing method.
    - Creates a router node and connects it to the RAG_chat, todo_chat and user_qa_chat nodes.
    - Visits the router node.
'''
walker query{
    has query:str = '';
    has user_session_id:str='';
    has session_chat_history:list=[];
    has user_data: 'data about the health status of the user' :dict={};
    has todo_list: 'The tasks to be done by the user in the future.' :list=[];
    can select_mode with session entry{
            self.user_data:dict = here.user_data;
            self.todo_list:list = here.todo_list;
            self.session_chat_history = here.session_chat_history;
            print(here.session_chat_history);
            # self.task_type:str = input('What is the routing method : '); # Get the routing method from the user.
            for message in self.session_chat_history {
                with st.chat_message(message["role"]) {
                    st.markdown(message["content"]);
                }
            }
            if [here -->] == [] {
                end = here;
                end ++> (end := router());
                end ++> RAG_chat();
                end ++> todo_chat();
                end ++> user_qa_chat();
                

            }
            if prompt := st.chat_input("What is up?") {
                self.query:str = prompt;
                with st.chat_message("user"){
                    st.markdown(self.query);
                }
                visit [-->];
            }
        }
}

'''
This is the router node which will be used to route the user query to the appropriate chat node.
TODO:Auto-routing feature not yet implemented
'''
node router {
    can route with query entry{
        task:task_type = task_type.TODO_TYPE;
        print(task, type(task));
    # if task == task_type.RAG_type {
    #     visit [-->](`?RAG_chat);
    # } el
    if task == task_type.QA_TYPE | task == None {
        visit [-->](`?user_qa_chat);
    } elif task == task_type.TODO_TYPE {
        visit [-->](`?todo_chat);
    }
    } 
}

'''
This is the RAG chat node which will be used to chat with the user using Retrival Augmented Generation.
TODO:Not yet implemented.
'''
node RAG_chat {
    can run_RAG with query entry {
        print('routed --> RAG');
    }    
}

'''
This is the TODO chat node which will be used to chat with the user using the todo list and user data.
'''
node todo_chat {
    can run_todo with query entry {
        print('routed --> TODO');
        answer = self.todo_chat_llm(todo_list=here.todo_list,user_data=here.user_data,session_chat_history=here.session_chat_history,query=here.query);
        print(answer);
        with st.chat_message("assistant"){
            stream = st.write(answer);
        }
        single_chat = {"role":"user","content":here.query};
        single_chat2 = {"role":"assistant","content":answer};
        here.session_chat_history.append(single_chat);
        here.session_chat_history.append(single_chat2);
        save_data(messages = here.session_chat_history) spawn self;
        disengage;
        }
    can 'You are a Health Assistant. Give a response based on the query using the chat history, my todo list and personal details.'
    todo_chat_llm(
        todo_list:'data regarding the todo list of the user':list,
        user_data:'personal details about the user':list,
        session_chat_history:'Previous questions and answers. Also go through these when giving the response':list,
        query:'The tasks to be done by the user in the future.':str
        ) -> 'response':str by llm();
}

'''
This is the user QA chat node which will be used to chat with the user using the user data.
TODO:Not yet implemented.
'''
node user_qa_chat {
    can run_user_qa with query entry {
        print('routed --> User QA');
        answer = self.qa_chat_llm(user_data=here.user_data,session_chat_history=here.session_chat_history,query=here.query);
        print(answer);
        
        single_chat = {"query":here.query,"answer":answer};
        here.session_chat_history.append(single_chat);
        # save_data(messages = here.session_chat_history) spawn self;
        disengage;
    }
    can 'You are a Health Assistant. Give a response based on the query using the chat history and user data.'
    qa_chat_llm(
        user_data:'personal details about the user':list,
        session_chat_history:'Previous questions and answers. Also go through these when giving the response':list,
        query:'The tasks to be done by the user in the future.':str
        ) -> 'response':str by llm();
}

'''
This is the data-saving wlker which will walk back to the session node and save the chat history.
'''
walker save_data{
    has messages:list = [];

    can go_to_router with todo_chat | user_qa_chat entry {
        visit [<--];
    }

    can go_to_session with router entry {
        visit [<--];
    }
    can saving_data with session entry {
        here.session_chat_history = self.messages;
        print("Data saved to session history.");
        disengage;
    }
}

'''
This is where we create the graph.
'''
walker create_graph{
    has user_data:dict = {};
    has todo_list:list = [];

    can generate_graph with `root entry{
        end = here; # Assign the current root node (here) to end
        end ++> (end := user()); # Create a user node and connect it to the end node. Assign the new user node to the end.
        end ++> data(user_data = self.user_data); # Create a data node with the user data and connect it to the end node.
        end ++> todo(todo_list = self.todo_list); # Create a todo node with the todo list and connect it to the end node.
        
    }
}

# '''Running the code'''
# with entry {
#     create_graph(
#         user_data={
#             "age": 20,
#             "Pressure": (120, 80),
#             "Married": False
#             },
#         todo_list=[
#             "Do heart surgery",
#             "Buy Bread",
#             "Have pizza for dinner"
#             ]
#     ) spawn root;

# }

can main {
    :g: state;
    st.title("Jac${Care}$");
    if st.button('New Chat'){
        state = PR_states.session_create;
    }
    
    if state == PR_states.init_PR {
        create_graph(
            user_data = {
                "age_years": 55,
                "Gender": "Male",
                "Height_cm": 175,
                "Weight_kg": 85,
                "BMI": 27.8,
                "Blood_Pressure_mmHg": (145, 90),
                "Married": True,
                "Smoking_Status": "Former",
                "Alcohol_Intake": "Moderate",
                "Physical_Activity_Level": "Low",
                "Cholesterol_Level_mg_dL": 240,
                "HDL_mg_dL": 40,
                "LDL_mg_dL": 160,
                "Triglycerides_mg_dL": 200,
                "Blood_Glucose_mg_dL": 180,
                "HbA1c_percent": 8.0,
                "Medications": ["Metformin", "Atorvastatin"],
                "Family_History": {
                    "Diabetes": True,
                    "Heart_Disease": True,
                    "Stroke": False
                },
                "Allergies": ["Penicillin"],
                "Regular_Checkups": True,
                "Last_Checkup_Date": "2024-05-10"
            },
            todo_list = [
                "Monitor blood pressure daily : 04/06/2024",
                "Take medication (Metformin, Atorvastatin) : 05/06/2024",
                "Schedule cardiology appointment : 10/06/2024",
                "Complete blood tests : 15/06/2024",
                "Attend diabetes education class : 20/06/2024",
                "Follow up with dietitian : 25/06/2024",
                "Exercise (30 minutes walk) : 26/06/2024",
                "Annual physical checkup : 01/07/2024",
                "Renew prescription for medications : 02/07/2024",
                "Check cholesterol levels : 05/07/2024",
                "Plan weekend getaway : 28/06/2024"
            ]) spawn root;
        print('Graph created');
        chat() spawn [root -->](`?user)[0]; # Spawn the chat walker with the user node.
        print("New Session");
        state = PR_states.chat_create;
        
        
    }
    elif state == PR_states.session_create {
        print("New Session");
        chat() spawn [root -->](`?user)[0]; # Spawn the chat walker with the user node.
        state = PR_states.chat_create;
        
    }
    
    elif state == PR_states.chat_create {
        print('Chatting with user');
        query() spawn [[root -->](`?user)[0] -->](`?session)[0];
        
    }
    
}

