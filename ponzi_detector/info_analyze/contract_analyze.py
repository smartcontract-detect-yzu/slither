import networkx as nx

from slither.core.declarations import Contract
from slither.core.declarations.function import Function
from slither.core.expressions import Identifier


class ContractInfo:
    def __init__(self, contract: Contract):
        self.name = contract.name
        self.contract = contract

        # 合约内部定义的结构体信息 <结构体名称, StructureContract>
        self.structs_info = {}

        # 直接调用 <>.send<> 和 <>.transfer<>接口的函数
        self.send_function_map = {}

        # 合约函数调用图
        self.funcid_2_graphid = {}  # <key:function.id value: call_graph.node_id>
        self.call_graph = None

        # 全局变量 <--> 函数对应关系表
        self.state_var_declare_function_map = {}  # <全局变量名称, slither.function>
        self.state_var_read_function_map = {}  # <全局变量名称, slither.function>
        self.state_var_write_function_map = {}  # <全局变量名称, slither.function>

        # 初始化: 合约信息抽取
        self.contract_info_analyze()

    def _struct_info(self):

        # 结构体定义信息抽取
        for structure in self.contract.structures:
            self.structs_info[structure.name] = structure

    def _stat_vars_info_in_contract(self):

        # 全局变量定义
        for v in self.contract.state_variables:
            if v.expression is None:
                exp = str(v.type) + " " + str(Identifier(v))
                self.state_var_declare_function_map[str(Identifier(v))] = {"type": str(v.type), "exp": exp}

        for function in self.contract.functions:

            # 全局变量定义
            if function.is_constructor or function.is_constructor_variables:
                for node in function.nodes:
                    for v in node.state_variables_written:
                        full_exp = "{} {}".format(str(v.type), node.expression)
                        self.state_var_declare_function_map[str(v)] = {
                            "fun": function,
                            "expr": node.expression,
                            "full_expr": full_exp
                        }

            else:
                # 全局变量读
                for v in function.state_variables_read:
                    if str(v) not in self.state_var_read_function_map:
                        self.state_var_read_function_map[str(v)] = [function]
                    else:
                        self.state_var_read_function_map[str(v)].append(function)

                # 全局变量写
                for v in function.state_variables_written:

                    if not function.can_send_eth():
                        continue  # NOTE:对于参与交易的函数，下面会进行重点分析

                    if str(v) not in self.state_var_write_function_map:
                        self.state_var_write_function_map[str(v)] = [function]
                    else:
                        self.state_var_write_function_map[str(v)].append(function)

    def _functions_with_transaction_call(self):

        for function in self.contract.functions:
            for node in function.nodes:
                if ".transfer(" in str(node.expression) or ".send(" in str(node.expression):
                    if function.name not in self.send_function_map:
                        self.send_function_map[function.id] = {
                            "id": function.id,
                            "name": function.name,
                            "function": function,
                            "exp": node.expression,
                            "node": node
                        }

    def _construct_call_graph(self):

        # 函数调用图
        call_graph = nx.DiGraph()
        call_graph.graph["name"] = self.contract.name
        edges = []
        duplicate = {}

        node_id = 0
        for function in self.contract.functions:

            if function.id not in self.funcid_2_graphid:
                call_graph.add_node(node_id, label=function.name, fid=function.id)
                self.funcid_2_graphid[function.id] = node_id
                node_id += 1

            from_node = self.funcid_2_graphid[function.id]
            for internal_call in function.internal_calls:

                if isinstance(internal_call, Function):
                    if internal_call.id not in self.funcid_2_graphid:
                        call_graph.add_node(node_id, label=internal_call.name, fid=internal_call.id)
                        self.funcid_2_graphid[internal_call.id] = node_id
                        node_id += 1

                    to_node = self.funcid_2_graphid[internal_call.id]
                    if "{}-{}".format(from_node, to_node) not in duplicate:
                        duplicate["{}-{}".format(from_node, to_node)] = 1
                        edges.append((from_node, to_node))
        call_graph.add_edges_from(edges)
        self.call_graph = call_graph

    def contract_info_analyze(self):
        self._struct_info()  # 获得结构体信息
        self._stat_vars_info_in_contract()  # 获得结构体信息
        self._functions_with_transaction_call()
        self._construct_call_graph()

    def debug_stat_var_info(self):

        print(u"===全局变量定义信息：")
        for var in self.state_var_declare_function_map:
            print("\t定义变量{}".format(str(var)))

            if "exp" in self.state_var_declare_function_map[var]:
                print("\t\t{}".format(self.state_var_declare_function_map[var]["exp"]))

            if "fun" in self.state_var_declare_function_map[var]:
                print("\t\t{}".format(self.state_var_declare_function_map[var]["full_expr"]))

        print("===全局变量读信息：")
        for var in self.state_var_read_function_map:

            print("读变量{}".format(str(var)))
            for func in self.state_var_read_function_map[var]:
                print("\t{}".format(func.name))

        print("===全局变量写信息：")
        for var in self.state_var_write_function_map:

            print("写变量{}".format(str(var)))
            for func in self.state_var_write_function_map[var]:
                print("\t{}".format(func.name))
